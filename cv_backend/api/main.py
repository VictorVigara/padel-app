"""
FastAPI application — CV backend REST API.

Endpoints:
  POST /analyze          Queue a new analysis job
  GET  /analyze/{job_id} Poll job status and retrieve results when done

Sprint 0: stubs only — endpoints write/read Supabase but call no real CV.
Real processing is driven by the job queue poller (job_queue.py), not by
these endpoints directly.

Run locally:
  uv run uvicorn cv_backend.api.main:app --reload
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone  # timedelta/timezone used in upload response

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from supabase import Client, create_client

from cv_backend.api.models import (
    AnalyzeRequest,
    CalibrationRequest,
    CalibrationResponse,
    JobStatusResponse,
    UploadUrlRequest,
    UploadUrlResponse,
)
from cv_backend.pipeline.court_projection import compute_homography
from cv_backend.storage.r2 import generate_presigned_upload_url

load_dotenv()

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
_SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

if not _SUPABASE_URL or not _SUPABASE_SERVICE_KEY:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set. "
        "Copy cv_backend/.env.example to cv_backend/.env and fill in values."
    )

supabase: Client = create_client(_SUPABASE_URL, _SUPABASE_SERVICE_KEY)

_R2_VIDEO_PREFIX = os.environ.get("CLOUDFLARE_R2_VIDEO_PREFIX", "videos")


app = FastAPI(title="Padel CV Backend", version="0.1.0")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/upload-url", response_model=UploadUrlResponse, status_code=200)
async def generate_upload_url(request: UploadUrlRequest) -> UploadUrlResponse:
    """
    Generate a pre-signed R2 PUT URL for direct video upload from the Flutter app.
    Flutter calls this first, then PUTs the compressed video directly to the URL.
    The object_key is returned so Flutter can pass it (as a full R2 URL) to POST /analyze.
    """
    object_key = f"{_R2_VIDEO_PREFIX}/{request.match_id}.mp4"
    expires_in = 3600  # 1 hour

    try:
        upload_url = generate_presigned_upload_url(
            object_key=object_key,
            content_type=request.content_type,
            content_length=request.content_length,
            expires_in=expires_in,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Failed to generate pre-signed URL: {exc}"
        ) from exc

    expires_at = (datetime.now(timezone.utc) + timedelta(seconds=expires_in)).isoformat()
    return UploadUrlResponse(
        upload_url=upload_url,
        object_key=object_key,
        expires_at=expires_at,
    )


@app.get("/analyze/{job_id}", response_model=JobStatusResponse)
async def get_analysis_status(job_id: str) -> JobStatusResponse:
    """
    Poll the status of an analysis job.
    When status == 'done', the response includes the full AnalysisResult.
    """
    try:
        job_result = (
            supabase.table("processing_jobs")
            .select("id, match_id, status, error_message")
            .eq("id", job_id)
            .maybe_single()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to fetch job: {exc}") from exc

    if job_result.data is None:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")

    job = job_result.data
    status = job["status"]

    if status not in ("done",):
        return JobStatusResponse(
            status=status,
            error=job.get("error_message"),
        )

    # Job is done — fetch the analysis result
    try:
        analysis_result = (
            supabase.table("match_analyses")
            .select("result")
            .eq("match_id", job["match_id"])
            .maybe_single()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Failed to fetch analysis result: {exc}"
        ) from exc

    results: dict | None = None
    if analysis_result.data:
        results = analysis_result.data.get("result")

    return JobStatusResponse(status=status, results=results)


@app.post("/analyze", response_model=JobStatusResponse, status_code=201)
async def start_analysis(request: AnalyzeRequest) -> JobStatusResponse:
    """
    Enqueue a match video for analysis.

    Note: Flutter currently creates jobs directly in Supabase via ProcessingJobRepository.
    This endpoint is an additive convenience route for API-driven flows.

    Idempotent by match_id: returns the existing job if one exists in a non-failed state.
    Requires a successful court calibration to exist before queueing.
    """
    # Require calibration before queueing — prevents an infinite queued state
    try:
        cal_result = (
            supabase.table("court_calibrations")
            .select("id")
            .eq("match_id", request.match_id)
            .eq("status", "success")
            .limit(1)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"DB error checking calibration: {exc}"
        ) from exc

    if not cal_result.data:
        raise HTTPException(
            status_code=422,
            detail="Court calibration not found for this match. Complete calibration before starting analysis.",
        )

    # Idempotent: return existing non-failed job if one already exists
    try:
        existing = (
            supabase.table("processing_jobs")
            .select("id, status")
            .eq("match_id", request.match_id)
            .neq("status", "failed")
            .maybe_single()
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"DB error checking existing job: {exc}"
        ) from exc

    if existing.data:
        return JobStatusResponse(status=existing.data["status"])

    # Create new queued job
    try:
        supabase.table("processing_jobs").insert(
            {
                "match_id": request.match_id,
                "video_url": request.video_url,
                "status": "queued",
                "retry_count": 0,
            }
        ).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Failed to create job: {exc}"
        ) from exc

    return JobStatusResponse(status="queued")


@app.post("/calibrate", response_model=CalibrationResponse, status_code=200)
async def calibrate_court(request: CalibrationRequest) -> CalibrationResponse:
    """
    Receive 12 court keypoints from Flutter, compute homography matrix,
    and store in court_calibrations table.
    """
    import base64
    import numpy as np
    import cv2

    # Filter out null keypoints and extract pixel coordinates
    keypoints_pixel = []
    keypoint_indices = []

    for i, kp in enumerate(request.keypoints):
        if kp is not None:
            keypoints_pixel.append((kp.x_px, kp.y_px))
            keypoint_indices.append(i)

    keypoints_count = len(keypoints_pixel)

    # Validate minimum keypoints
    if keypoints_count < 4:
        try:
            supabase.table("court_calibrations").insert({
                "match_id": request.match_id,
                "keypoints": [kp.model_dump() if kp else None for kp in request.keypoints],
                "keypoints_count": keypoints_count,
                "status": "failed",
                "error_message": f"Insufficient keypoints: {keypoints_count} (minimum 4)",
            }).execute()
        except Exception:
            pass  # Best effort

        return CalibrationResponse(
            success=False,
            message=f"Need at least 4 keypoints, got {keypoints_count}",
        )

    # Compute homography (pass indices so court coords are correctly paired)
    try:
        H = compute_homography(keypoints_pixel, keypoint_indices)
        H_list = H.tolist()  # Convert numpy array to list for JSON

        # Store in database
        supabase.table("court_calibrations").upsert({
            "match_id": request.match_id,
            "keypoints": [kp.model_dump() if kp else None for kp in request.keypoints],
            "keypoints_count": keypoints_count,
            "homography_matrix": H_list,
            "status": "success",
            "error_message": None,
        }, on_conflict="match_id").execute()

        # Debug visualization (if enabled and frame provided)
        debug_enabled = os.environ.get("DEBUG_SAVE_CALIBRATION_IMAGE", "false").lower() == "true"
        if debug_enabled and request.frame_base64:
            try:
                # Decode base64 image
                img_data = base64.b64decode(request.frame_base64)
                img_array = np.frombuffer(img_data, dtype=np.uint8)
                img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

                if img is not None:
                    # Draw keypoints
                    for i, kp in enumerate(request.keypoints):
                        if kp is not None:
                            x, y = int(kp.x_px), int(kp.y_px)
                            # Draw circle
                            cv2.circle(img, (x, y), 10, (0, 255, 0), 2)
                            # Draw label
                            cv2.putText(img, kp.label, (x + 15, y - 10),
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

                    # Save to /tmp
                    output_path = f"/tmp/debug_calibration_{request.match_id}.jpg"
                    cv2.imwrite(output_path, img)
                    print(f"Debug: Saved calibration visualization to {output_path}")
            except Exception as e:
                print(f"Debug visualization failed: {e}")

        return CalibrationResponse(
            success=True,
            message=f"Homography computed successfully from {keypoints_count} keypoints",
            homography_matrix=H_list,
        )

    except ValueError as exc:
        # RANSAC failed or other computation error
        try:
            supabase.table("court_calibrations").upsert({
                "match_id": request.match_id,
                "keypoints": [kp.model_dump() if kp else None for kp in request.keypoints],
                "keypoints_count": keypoints_count,
                "status": "failed",
                "error_message": str(exc),
            }, on_conflict="match_id").execute()
        except Exception:
            pass  # Best effort

        return CalibrationResponse(
            success=False,
            message=f"Homography computation failed: {exc}",
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Calibration failed: {exc}"
        ) from exc
