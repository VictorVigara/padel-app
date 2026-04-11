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

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from supabase import Client, create_client

from cv_backend.api.models import AnalyzeRequest, AnalyzeResponse, JobStatusResponse

load_dotenv()

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
_SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

if not _SUPABASE_URL or not _SUPABASE_SERVICE_KEY:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set. "
        "Copy cv_backend/.env.example to cv_backend/.env and fill in values."
    )

supabase: Client = create_client(_SUPABASE_URL, _SUPABASE_SERVICE_KEY)

app = FastAPI(title="Padel CV Backend", version="0.1.0")


@app.post("/analyze", response_model=AnalyzeResponse, status_code=201)
async def queue_analysis(request: AnalyzeRequest) -> AnalyzeResponse:
    """
    Queue a new analysis job.
    Called by Flutter after a video upload to Supabase Storage completes.
    """
    try:
        result = (
            supabase.table("processing_jobs")
            .insert({"match_id": request.match_id, "video_url": request.video_url})
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to queue job: {exc}") from exc

    job_id: str = result.data[0]["id"]
    return AnalyzeResponse(job_id=job_id)


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
