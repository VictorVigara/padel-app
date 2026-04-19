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

    # 2. Mark as processing
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
        # 3. Download video to local temp path (stub — no real download yet)
        # TODO Sprint 1: download from Supabase Storage before calling analyze_match
        local_video_path = video_url  # placeholder — no file actually exists

        # 3.5. Fetch court calibration if available
        homography_matrix = None
        try:
            cal_result = (
                client.table("court_calibrations")
                .select("homography_matrix, status")
                .eq("match_id", match_id)
                .eq("status", "success")
                .maybe_single()
                .execute()
            )
            if cal_result.data:
                homography_matrix = cal_result.data["homography_matrix"]
                logger.info("Job %s: Using calibration data for match %s", job_id, match_id)
            else:
                logger.warning("Job %s: No calibration data found, proceeding without court projection", job_id)
        except Exception as exc:
            logger.warning("Job %s: Failed to fetch calibration: %s", job_id, exc)

        # 4. Run CV pipeline (stub in Sprint 0 — returns dummy data)
        analysis_result = analyze_match(local_video_path, AnalysisConfig(), homography_matrix=homography_matrix)

        # 5. Write result to match_analyses
        result_dict = dataclasses.asdict(analysis_result)
        client.table("match_analyses").upsert(
            {
                "match_id": match_id,
                "status": "done",
                "result": result_dict,
                "processing_completed_at": datetime.datetime.utcnow().isoformat(),
            },
            on_conflict="match_id",
        ).execute()

        # 6. Mark job done
        client.table("processing_jobs").update(
            {
                "status": "done",
                "completed_at": datetime.datetime.utcnow().isoformat(),
            }
        ).eq("id", job_id).execute()

        logger.info("Job %s completed successfully.", job_id)

    except Exception as exc:
        logger.exception("Job %s failed: %s", job_id, exc)

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
