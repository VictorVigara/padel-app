"""
Supabase helpers for processing_jobs job state management.

No CV/GPU/pipeline imports — this module is safe to run on CPU-only containers.
All functions take an explicit supabase Client so callers control construction.
"""
from __future__ import annotations

import datetime
import logging
import os
from typing import Any

from supabase import Client, create_client

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
DISPATCHING_TIMEOUT_MINUTES = 10


def _now() -> str:
    return datetime.datetime.now(datetime.UTC).isoformat()


def get_supabase_client() -> Client:
    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_SERVICE_KEY"]
    return create_client(url, key)


def get_oldest_queued_job(client: Client) -> dict[str, Any] | None:
    """Fetch the oldest job with status='queued'. Returns None if queue is empty."""
    result = (
        client.table("processing_jobs")
        .select("id, match_id, video_url, retry_count")
        .eq("status", "queued")
        .order("created_at", desc=False)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def claim_job(client: Client, job_id: str) -> bool:
    """
    Atomically transition a job from 'queued' → 'dispatching'.

    The double .eq() makes this safe against concurrent poller instances:
    only one will see updated.data as non-empty.

    Returns True if this caller claimed the job, False if already claimed.
    """
    updated = (
        client.table("processing_jobs")
        .update({"status": "dispatching"})
        .eq("id", job_id)
        .eq("status", "queued")
        .execute()
    )
    if updated.data:
        logger.info("[queue] Claimed job %s: queued → dispatching", job_id)
        return True
    logger.info("[queue] Job %s already claimed by another instance, skipping", job_id)
    return False


def get_job(client: Client, job_id: str) -> dict[str, Any] | None:
    """Fetch a single processing_job row by id."""
    result = (
        client.table("processing_jobs")
        .select("id, match_id, video_url, retry_count, status")
        .eq("id", job_id)
        .maybe_single()
        .execute()
    )
    return result.data


def get_calibration(client: Client, match_id: str) -> dict[str, Any] | None:
    """Return the most recent successful court calibration for match_id, or None."""
    result = (
        client.table("court_calibrations")
        .select("homography_matrix, status")
        .eq("match_id", match_id)
        .eq("status", "success")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def mark_job_processing(client: Client, job_id: str, match_id: str) -> bool:
    """
    Transition job to 'processing' and upsert a pending match_analyses row.

    Uses a status guard so a stale worker cannot overwrite a job that was already
    moved to done/failed by another worker or manually.

    Returns True if the transition succeeded, False if the job was in an
    unexpected state (caller should abort processing).
    """
    now = _now()
    result = (
        client.table("processing_jobs")
        .update({"status": "processing", "started_at": now})
        .eq("id", job_id)
        .in_("status", ["dispatching", "queued"])
        .execute()
    )
    if not result.data:
        logger.warning(
            "[queue] Job %s was not in dispatching/queued state; skipping processing transition",
            job_id,
        )
        return False

    logger.info("[queue] Job %s: dispatching → processing", job_id)

    client.table("match_analyses").upsert(
        {
            "match_id": match_id,
            "status": "pending",
            "processing_started_at": now,
        },
        on_conflict="match_id",
    ).execute()

    return True


def mark_job_done(
    client: Client,
    job_id: str,
    match_id: str,
    result_dict: dict,
) -> None:
    """Write results and mark job 'done'."""
    now = _now()
    client.table("match_analyses").upsert(
        {
            "match_id": match_id,
            "status": "done",
            "result": result_dict,
            "processing_completed_at": now,
        },
        on_conflict="match_id",
    ).execute()
    client.table("processing_jobs").update(
        {"status": "done", "completed_at": now}
    ).eq("id", job_id).execute()
    logger.info("[queue] Job %s: processing → done", job_id)


def mark_job_failed(
    client: Client,
    job_id: str,
    match_id: str,
    error: str,
    retry_count: int | None,
) -> None:
    """
    Re-queue the job for retry, or permanently mark it failed after MAX_RETRIES.
    retry_count is the count before this failure (0-indexed).
    """
    retry_count = retry_count or 0
    new_count = retry_count + 1
    now = _now()

    if new_count >= MAX_RETRIES:
        client.table("processing_jobs").update(
            {
                "status": "failed",
                "retry_count": new_count,
                "error_message": error,
                "completed_at": now,
            }
        ).eq("id", job_id).execute()
        client.table("match_analyses").upsert(
            {
                "match_id": match_id,
                "status": "failed",
                "error_message": error,
                "processing_completed_at": now,
            },
            on_conflict="match_id",
        ).execute()
        logger.error(
            "[queue] Job %s: processing → failed (permanent, %d/%d attempts)",
            job_id, new_count, MAX_RETRIES,
        )
    else:
        client.table("processing_jobs").update(
            {
                "status": "queued",
                "retry_count": new_count,
                "error_message": error,
            }
        ).eq("id", job_id).execute()
        logger.warning(
            "[queue] Job %s: processing → queued (retry %d/%d)",
            job_id, new_count, MAX_RETRIES,
        )


def reset_stuck_dispatching_jobs(client: Client) -> None:
    """
    Reset jobs stuck in 'dispatching' for longer than DISPATCHING_TIMEOUT_MINUTES
    back to 'queued'. Only touches 'dispatching' — never 'processing' jobs.

    Selects affected rows first, then resets each individually, to avoid
    depending on Supabase returning updated rows from .update().
    """
    cutoff = (
        datetime.datetime.now(datetime.UTC)
        - datetime.timedelta(minutes=DISPATCHING_TIMEOUT_MINUTES)
    ).isoformat()

    stuck = (
        client.table("processing_jobs")
        .select("id")
        .eq("status", "dispatching")
        .lt("updated_at", cutoff)
        .execute()
    )

    if not stuck.data:
        return

    for job in stuck.data:
        client.table("processing_jobs").update(
            {"status": "queued"}
        ).eq("id", job["id"]).execute()
        logger.warning(
            "[queue] Reset stuck dispatching job %s: dispatching → queued", job["id"]
        )
