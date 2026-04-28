# Modal (serverless GPU) infrastructure wrapper.
# This is the ONLY file that knows about Modal. Switching to RunPod means
# rewriting only this file — analyze_match() stays untouched.
#
# Sprint 0: app and poller are defined but the poller calls the stub
# analyze_match() which returns dummy data. No GPU image is attached yet.
#
# Sprint 2: swap the base image for one with torch/ultralytics/boxmot,
# add a GPU=A10G annotation to run_poller, and replace the stub with
# real YOLO tracking.

import modal

app = modal.App("padel-cv-backend")

# Sprint 2: GPU-enabled image with full CV dependencies
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("libgl1-mesa-glx", "libglib2.0-0")
    .pip_install_from_requirements("cv_backend/requirements.txt")
    .add_local_python_source(
        "cv_backend",
        ignore=["**/__pycache__", "**/*.pyc", "**/*.pyo", "scripts/", ".venv/"],
    )
)


@app.function(
    image=image,
    gpu="T4",  # Sprint 2: GPU required for YOLO tracking
    secrets=[modal.Secret.from_name("padel-secrets")],
    schedule=modal.Period(seconds=30),
)
def run_poller() -> None:
    """Scheduled function — polls for one queued job every 30 seconds.

    job_queue.poll_once() creates its own Supabase client from env vars
    (injected via the padel-secrets Modal secret).
    """
    import asyncio
    from cv_backend.api.job_queue import poll_once, _get_supabase_client
    asyncio.run(poll_once(_get_supabase_client()))
