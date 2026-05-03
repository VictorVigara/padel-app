"""
GPU worker entry point.

process_job(job_id) runs the full CV pipeline for one job.
All heavy imports (torch, ultralytics, boxmot, pipeline) are deferred inside
the function body so this module is importable in CPU-only contexts.
"""
from __future__ import annotations


def process_job(job_id: str) -> None:
    import dataclasses
    import logging
    import os
    from pathlib import Path

    logger = logging.getLogger(__name__)

    # All CV/GPU/pipeline imports deferred — safe to import this module on CPU
    from cv_backend.jobs.queue import (
        get_supabase_client,
        get_job,
        get_calibration,
        mark_job_processing,
        mark_job_done,
        mark_job_failed,
    )
    from cv_backend.storage.r2 import (
        get_r2_client,
        extract_object_key,
        download_from_r2,
        delete_from_r2,
    )
    from cv_backend.pipeline.analyze_match import AnalysisConfig, analyze_match

    client = get_supabase_client()
    job = get_job(client, job_id)

    if not job:
        logger.error("[worker] Job %s not found in DB — aborting", job_id)
        return

    # Safety check: only process jobs in dispatching state (or queued as fallback)
    if job["status"] not in ("dispatching", "queued"):
        logger.warning(
            "[worker] Job %s has unexpected status '%s' — skipping",
            job_id, job["status"],
        )
        return

    match_id: str = job["match_id"]
    video_url: str = job["video_url"]
    retry_count: int = job["retry_count"] or 0

    # Verify calibration exists (poller already checked, but GPU cold-start can race)
    cal = get_calibration(client, match_id)
    if not cal:
        logger.warning(
            "[worker] Job %s: calibration missing for match %s — re-queuing (no retry burned)",
            job_id, match_id,
        )
        client.table("processing_jobs").update({"status": "queued"}).eq("id", job_id).execute()
        return

    # Transition to processing — abort if another worker already claimed this
    if not mark_job_processing(client, job_id, match_id):
        logger.warning("[worker] Job %s could not transition to processing — aborting", job_id)
        return

    bucket = os.environ["CLOUDFLARE_R2_BUCKET"]
    object_key = extract_object_key(video_url, bucket)
    local_video_path = f"/tmp/padel_{job_id}.mp4"

    try:
        logger.info("[worker] Job %s: downloading %s from R2", job_id, object_key)
        s3 = get_r2_client()
        download_from_r2(s3, bucket, object_key, local_video_path)
        size_mb = Path(local_video_path).stat().st_size / 1_048_576
        logger.info("[worker] Job %s: downloaded %.1f MB", job_id, size_mb)

        logger.info("[worker] Job %s: starting CV pipeline", job_id)
        result = analyze_match(
            local_video_path,
            AnalysisConfig(),
            homography_matrix=cal["homography_matrix"],
        )
        logger.info(
            "[worker] Job %s: CV pipeline complete — %d players tracked",
            job_id, len(result.players),
        )

        logger.info("[worker] Job %s: uploading results to Supabase", job_id)
        mark_job_done(client, job_id, match_id, dataclasses.asdict(result))
        logger.info("[worker] Job %s: done", job_id)

        # R2 deletion is opt-in via env var — defaults to false for early testing
        if os.environ.get("DELETE_VIDEO_AFTER_PROCESSING", "false").lower() == "true":
            try:
                logger.info("[worker] Job %s: deleting R2 object %s", job_id, object_key)
                delete_from_r2(s3, bucket, object_key)
                logger.info("[worker] Job %s: R2 object deleted", job_id)
            except Exception as del_exc:
                logger.warning(
                    "[worker] Job %s: R2 delete failed (non-fatal): %s", job_id, del_exc
                )
        else:
            logger.info(
                "[worker] Job %s: R2 deletion skipped (DELETE_VIDEO_AFTER_PROCESSING not set)",
                job_id,
            )

    except Exception as exc:
        logger.exception("[worker] Job %s failed: %s", job_id, exc)
        mark_job_failed(client, job_id, match_id, str(exc), retry_count)

    finally:
        try:
            Path(local_video_path).unlink(missing_ok=True)
        except Exception as cleanup_exc:
            logger.warning(
                "[worker] Job %s: temp file cleanup failed: %s", job_id, cleanup_exc
            )
