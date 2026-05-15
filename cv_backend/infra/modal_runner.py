"""
Modal deployment — three functions.

  web                CPU-only  FastAPI ASGI endpoint
  process_match_gpu  GPU T4    Video analysis worker (only function with GPU)

Deploy (run from the repo root, not from inside cv_backend/):
  uv run python -m modal deploy cv_backend/infra/modal_runner.py

  Prerequisites: padeldet must be installed in the uv venv (code only, no heavy deps):
    uv pip install --no-deps -e ../padeldet
  This is a one-time step; the install persists in the venv across deploys.
  The uv venv's modal binary may have a stale shebang; use "python -m modal" instead.

Flutter --dart-define after deploy:
  BACKEND_URL=https://<yourname>--padel-cv-backend-web.modal.run
"""
import modal

app = modal.App("padel-cv-backend")
secrets = [modal.Secret.from_name("padel-secrets")]

# Lightweight image — FastAPI + Supabase + R2 + OpenCV for /calibrate.
# Does NOT include torch / ultralytics / boxmot — those are GPU-worker only.
api_image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("libgl1-mesa-glx", "libglib2.0-0")
    .pip_install(
        "fastapi",
        "uvicorn[standard]",
        "supabase==2.28.3",
        "boto3",
        "botocore",
        "python-dotenv",
        "numpy",
        "opencv-python",
        "pydantic==2.12.5",
    )
    .add_local_python_source(
        "cv_backend",
        ignore=["**/__pycache__", "**/*.pyc", "**/.venv/**", "**/*.pt", "**/scripts/**"],
    )
)

# Full CV image — adds torch + ultralytics + boxmot + YOLO weights baked in.
# Only used by process_match_gpu.
worker_image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("libgl1-mesa-glx", "libglib2.0-0")
    .pip_install_from_requirements("cv_backend/requirements.txt")
    .run_commands(
        # Pre-bake YOLO weights into the image layer so every GPU cold-start
        # doesn't re-download ~52MB from the internet.
        "python -c \"from ultralytics import YOLO; YOLO('yolov8m.pt')\"",
    )
    .add_local_python_source(
        "padeldet",
        ignore=["**/__pycache__", "**/*.pyc", "**/.venv/**", "**/*.pt", "**/scripts/**", "**/data/**"],
    )
    .add_local_python_source(
        "cv_backend",
        ignore=["**/__pycache__", "**/*.pyc", "**/.venv/**", "**/*.pt", "**/scripts/**"],
    )
)


# ── 1. CPU-only web endpoint ──────────────────────────────────────────────────
@app.function(image=api_image, secrets=secrets, cpu=1.0, memory=512)
@modal.asgi_app()
def web():
    from cv_backend.api.main import app as fastapi_app
    return fastapi_app


# ── 2. T4 GPU worker — the ONLY function with a GPU ──────────────────────────
@app.function(
    image=worker_image,
    secrets=secrets,
    gpu="T4",       # ← only this function gets a GPU
    cpu=2.0,
    memory=8192,
    timeout=3600,   # 90-min match takes ~10 min on T4; 60 min is the safe ceiling
)
def process_match_gpu(job_id: str) -> None:
    from cv_backend.jobs.worker import process_job
    process_job(job_id)
