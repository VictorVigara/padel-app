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
from datetime import datetime, timedelta, timezone

import boto3
from botocore.config import Config
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from supabase import Client, create_client

from cv_backend.api.models import (
    JobStatusResponse,
    UploadUrlRequest,
    UploadUrlResponse,
)

load_dotenv()

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
_SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

if not _SUPABASE_URL or not _SUPABASE_SERVICE_KEY:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set. "
        "Copy cv_backend/.env.example to cv_backend/.env and fill in values."
    )

supabase: Client = create_client(_SUPABASE_URL, _SUPABASE_SERVICE_KEY)

_R2_ACCOUNT_ID = os.environ.get("CLOUDFLARE_R2_ACCOUNT_ID", "")
_R2_ACCESS_KEY = os.environ.get("CLOUDFLARE_R2_ACCESS_KEY", "")
_R2_SECRET_KEY = os.environ.get("CLOUDFLARE_R2_SECRET_KEY", "")
_R2_BUCKET = os.environ.get("CLOUDFLARE_R2_BUCKET", "padel-match-videos")


def _get_r2_client():
    """Return a boto3 S3 client configured for Cloudflare R2."""
    return boto3.client(
        "s3",
        endpoint_url=f"https://{_R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=_R2_ACCESS_KEY,
        aws_secret_access_key=_R2_SECRET_KEY,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


app = FastAPI(title="Padel CV Backend", version="0.1.0")


@app.post("/upload-url", response_model=UploadUrlResponse, status_code=200)
async def generate_upload_url(request: UploadUrlRequest) -> UploadUrlResponse:
    """
    Generate a pre-signed R2 PUT URL for direct video upload from the Flutter app.
    Flutter calls this first, then PUTs the compressed video directly to the URL.
    The object_key is returned so Flutter can pass it (as a full R2 URL) to POST /analyze.
    """
    if not _R2_ACCOUNT_ID or not _R2_ACCESS_KEY or not _R2_SECRET_KEY:
        raise HTTPException(status_code=500, detail="R2 credentials not configured")

    object_key = f"videos/{request.match_id}.mp4"
    expires_in = 3600  # 1 hour

    try:
        upload_url = _get_r2_client().generate_presigned_url(
            "put_object",
            Params={
                "Bucket": _R2_BUCKET,
                "Key": object_key,
                "ContentType": request.content_type,
                "ContentLength": request.content_length,
            },
            ExpiresIn=expires_in,
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

    if status != "done":
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

    return JobStatusResponse(status="done", results=results)
