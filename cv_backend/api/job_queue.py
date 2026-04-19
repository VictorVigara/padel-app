"""
Supabase-based async job queue poller.

Polls the `processing_jobs` table every 30 seconds, picks up queued jobs,
runs the CV pipeline (stub in Sprint 0), writes results to `match_analyses`,
and updates job status throughout.

Retry policy: up to 3 attempts per job. After 3 failures, status = 'failed'
and the user is notified (notification mechanism: Sprint 3).

Sprint 0 stubs:
  - Video download is skipped (no real file, just a path string)
  - analyze_match() returns dummy data

Entry point for the infra layer (modal_runner.py, runpod_runner.py):
  asyncio.run(run_poller())

For local testing:
  uv run python -m cv_backend.api.job_queue
"""

from __future__ import annotations

import asyncio
import dataclasses
import datetime
import logging
import os

from dotenv import load_dotenv
from supabase import Client, create_client

from cv_backend.pipeline.analyze_match import AnalysisConfig, analyze_match

load_dotenv()

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
POLL_INTERVAL_S = 30


def _get_supabase_client() -> Client:
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not url or not key:
        raise RuntimeError(
            "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set. "
            "Copy cv_backend/.env.example to cv_backend/.env."
        )
    return create_client(url, key)


async def poll_once(client: Client) -> None:
    """
    Pick up one queued job and process it.

    Uses a fetch-then-update pattern (single worker on Modal — safe for Sprint 0).
    # TODO Sprint 2: switch to SELECT ... FOR UPDATE SKIP LOCKED via raw SQL RPC
    # when scaling to multiple concurrent workers to prevent double-processing.
    """
    # 1. Fetch the oldest queued job
    result = (
        client.table("processing_jobs")
        .select("id, match_id, video_url, retry_count")
        .eq("status", "queued")
        .order("created_at", desc=False)
        .limit(1)
        .execute()
    )

    if not result.data:
        logger.debug("No queued jobs found.")
        return

    job = result.data[0]
    job_id: str = job["id"]
    match_id: str = job["match_id"]
    video_url: str = job["video_url"]
    retry_count: int = job["retry_count"]

    logger.info("Picked up job %s (match %s, attempt %d)", job_id, match_id, retry_count + 1)

    # 2. Check if court calibration is ready (don't process until user finishes calibration)
    cal_result = (
        client.table("court_calibrations")
        .select("homography_matrix, status")
        .eq("match_id", match_id)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )

    if not cal_result.data:
        logger.info("Job %s: Court calibration not ready yet for match %s. Will check again in next poll cycle.", job_id, match_id)
        return

    if cal_result.data[0]["status"] != "success":
        logger.warning("Job %s: Court calibration failed for match %s: %s",
                      job_id, match_id, cal_result.data[0].get("error_message", "unknown error"))
        return

    homography_matrix = cal_result.data[0]["homography_matrix"]
    logger.info("Job %s: Court calibration ready for match %s, proceeding with processing", job_id, match_id)

    # 3. Mark as processing (only after calibration is confirmed)
    client.table("processing_jobs").update(
        {"status": "processing", "started_at": datetime.datetime.utcnow().isoformat()}
    ).eq("id", job_id).execute()

    # Upsert a pending row in match_analyses so Flutter can see "processing" state
    client.table("match_analyses").upsert(
        {
            "match_id": match_id,
            "status": "pending",
            "processing_started_at": datetime.datetime.utcnow().isoformat(),
        },
        on_conflict="match_id",
    ).execute()

    try:
        # 4. Download video from R2 to local temp file
        import tempfile
        import boto3
        from pathlib import Path

        # Initialize S3 client for R2
        account_id = os.environ["CLOUDFLARE_R2_ACCOUNT_ID"]
        endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
        s3_client = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=os.environ["CLOUDFLARE_R2_ACCESS_KEY"],
            aws_secret_access_key=os.environ["CLOUDFLARE_R2_SECRET_KEY"],
            region_name='auto'
        )

        # Parse video_url to extract object key
        # Format: "https://<account>.r2.cloudflarestorage.com/<bucket>/<key>"
        bucket = os.environ["CLOUDFLARE_R2_BUCKET"]

        # Extract full key including folder structure (e.g., "videos/123.mp4")
        if f"/{bucket}/" in video_url:
            key = video_url.split(f"/{bucket}/", 1)[1]
        else:
            # Fallback: extract everything after the 4th slash
            parts = video_url.split('/')
            key = '/'.join(parts[4:]) if len(parts) > 4 else parts[-1]

        # Download to temp file
        tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        tmp_file.close()
        local_video_path = tmp_file.name

        try:
            with open(local_video_path, 'wb') as f:
                s3_client.download_fileobj(bucket, key, f)

            logger.info("Job %s: Downloaded video to %s, size: %d bytes",
                       job_id, local_video_path, Path(local_video_path).stat().st_size)
        except Exception as download_exc:
            # Clean up temp file on download failure
            Path(local_video_path).unlink(missing_ok=True)
            raise RuntimeError(f"Failed to download video from R2: {download_exc}") from download_exc

        # 5. Run CV pipeline
        logger.info("Job %s: Starting CV pipeline...", job_id)
        analysis_result = analyze_match(local_video_path, AnalysisConfig(), homography_matrix=homography_matrix)
        logger.info("Job %s: CV pipeline complete. Players: %d", job_id, len(analysis_result.players))

        # 6. Write result to match_analyses
        result_dict = dataclasses.asdict(analysis_result)
        logger.info("Job %s: Result dict preview:", job_id)
        logger.info("  Players: %d", len(result_dict.get('players', [])))
        for i, p in enumerate(result_dict.get('players', [])[:2]):
            logger.info("  Player %d: distance=%.2f, coverage=%.2f%%",
                       i, p.get('total_distance_m', 0), p.get('court_coverage_pct', 0))
        client.table("match_analyses").upsert(
            {
                "match_id": match_id,
                "status": "done",
                "result": result_dict,
                "processing_completed_at": datetime.datetime.utcnow().isoformat(),
            },
            on_conflict="match_id",
        ).execute()

        # 7. Delete raw video from R2 (processed video is no longer needed)
        try:
            s3_client.delete_object(Bucket=bucket, Key=key)
            logger.info("Job %s: Deleted raw video from R2: %s", job_id, key)
        except Exception as delete_exc:
            logger.warning("Job %s: Failed to delete video from R2 (non-fatal): %s", job_id, delete_exc)

        # 8. Clean up local temp file
        Path(local_video_path).unlink(missing_ok=True)

        # 9. Mark job done
        client.table("processing_jobs").update(
            {
                "status": "done",
                "completed_at": datetime.datetime.utcnow().isoformat(),
            }
        ).eq("id", job_id).execute()

        logger.info("Job %s completed successfully.", job_id)

    except Exception as exc:
        logger.exception("Job %s failed: %s", job_id, exc)

        # Clean up local temp file if it exists
        if 'local_video_path' in locals():
            from pathlib import Path
            Path(local_video_path).unlink(missing_ok=True)

        new_retry_count = retry_count + 1
        if new_retry_count >= MAX_RETRIES:
            # Exhausted retries — mark failed
            client.table("processing_jobs").update(
                {
                    "status": "failed",
                    "retry_count": new_retry_count,
                    "error_message": str(exc),
                    "completed_at": datetime.datetime.utcnow().isoformat(),
                }
            ).eq("id", job_id).execute()

            client.table("match_analyses").upsert(
                {
                    "match_id": match_id,
                    "status": "failed",
                    "error_message": str(exc),
                    "processing_completed_at": datetime.datetime.utcnow().isoformat(),
                },
                on_conflict="match_id",
            ).execute()

            logger.error("Job %s permanently failed after %d attempts.", job_id, new_retry_count)
            # TODO Sprint 3: push notification to user ("Analysis failed — no charge applied")
        else:
            # Re-queue for retry
            client.table("processing_jobs").update(
                {"status": "queued", "retry_count": new_retry_count, "error_message": str(exc)}
            ).eq("id", job_id).execute()

            logger.warning(
                "Job %s failed, re-queued (attempt %d/%d).", job_id, new_retry_count, MAX_RETRIES
            )


async def run_poller(interval_s: int = POLL_INTERVAL_S) -> None:
    """
    Main polling loop. Entry point for the infra layer.

    Runs forever — the infra wrapper (modal_runner.py) is responsible for
    termination and crash recovery.
    """
    client = _get_supabase_client()
    logger.info("Job queue poller started (interval=%ds, max_retries=%d).", interval_s, MAX_RETRIES)

    while True:
        try:
            await poll_once(client)
        except Exception as exc:
            # poll_once itself crashed (e.g. network error fetching jobs) — log and continue
            logger.exception("Poller loop error: %s", exc)
        await asyncio.sleep(interval_s)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(run_poller())
