"""
Modal deployment — three functions.

  web                CPU-only  FastAPI ASGI endpoint
  run_poller         CPU-only  Scheduled dispatcher (every 30s, max 1 job/tick)
  process_match_gpu  GPU T4    Video analysis worker (only function with GPU)

Deploy (run from the repo root, not from inside cv_backend/):
  modal deploy cv_backend/infra/modal_runner.py

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


# ── 2. CPU-only scheduled dispatcher ─────────────────────────────────────────
# This function must NEVER have a gpu= annotation.
# It only does a Supabase query and calls .spawn() — no CV/ML work.
@app.function(
    image=api_image,
    secrets=secrets,
    schedule=modal.Period(seconds=30),
    cpu=0.25,
    memory=256,
    timeout=60,
)
def run_poller() -> None:
    import logging
    logger = logging.getLogger(__name__)

    from cv_backend.jobs.queue import (
        get_supabase_client,
        get_oldest_queued_job,
        claim_job,
        get_calibration,
        reset_stuck_dispatching_jobs,
    )

    print("[poller] Tick — checking for queued jobs")
    client = get_supabase_client()
    print("[poller] Supabase client created OK")

    # Reset any jobs stuck in 'dispatching' for >10 minutes before looking for new work
    reset_stuck_dispatching_jobs(client)

    # Process at most 1 job per 30-second tick (MVP bound)
    job = get_oldest_queued_job(client)
    if not job:
        print("[poller] No queued jobs — idle")
        logger.info("[poller] No queued jobs.")
        return

    print(f"[poller] Found job: id={job['id']} match_id={job['match_id']}")

    cal = get_calibration(client, job["match_id"])
    if not cal:
        print(f"[poller] Job {job['id']}: no successful calibration for match {job['match_id']}, skipping")
        logger.info("[poller] Job %s: calibration not ready, skipping.", job["id"])
        return

    print(f"[poller] Calibration found for match {job['match_id']}, claiming job {job['id']}")

    # Atomically claim the job — only spawn after a successful claim
    if not claim_job(client, job["id"]):
        return  # claim_job already logged the skip reason

    print(f"[poller] Spawning GPU worker for job {job['id']}")
    logger.info("[poller] Dispatching job %s to GPU worker.", job["id"])
    process_match_gpu.spawn(job["id"])


# ── 3. T4 GPU worker — the ONLY function with a GPU ──────────────────────────
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
