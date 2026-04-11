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

# Lightweight image for Sprint 0 — no heavy CV deps.
# In Sprint 2 replace with:
#   modal.Image.debian_slim().pip_install("torch", "ultralytics", "boxmot")
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("fastapi", "uvicorn", "supabase", "pydantic", "python-dotenv")
)


@app.function(image=image, secrets=[modal.Secret.from_name("padel-secrets")])
def process_job(job_id: str) -> None:
    """Process a single queued job. Called by the poller."""
    import asyncio
    from cv_backend.api.job_queue import poll_once, supabase  # noqa: F401
    # Sprint 0: poll_once fetches the job by status, not by id.
    # Sprint 2: pass job_id directly to avoid re-fetching.
    asyncio.run(poll_once(supabase))


@app.function(image=image, secrets=[modal.Secret.from_name("padel-secrets")], schedule=modal.Period(seconds=30))
def run_poller() -> None:
    """Scheduled function — polls for queued jobs every 30 seconds."""
    import asyncio
    from cv_backend.api.job_queue import poll_once, supabase  # noqa: F401
    asyncio.run(poll_once(supabase))
