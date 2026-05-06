"""
Pydantic v2 request/response models for the CV backend REST API.

REST contract (from CLAUDE.md):
  GET  /analyze/{id}  path: job_id           → JobStatusResponse

The `results` field in JobStatusResponse is a plain dict, not a typed Pydantic
model — AnalysisResult is a dataclass in pipeline/analyze_match.py and is
serialised with dataclasses.asdict() before insertion into Supabase and before
returning from the API. No need to duplicate the schema here.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict


class JobStatusResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: Literal["queued", "dispatching", "processing", "done", "failed"]
    job_id: str | None = None
    progress_pct: float | None = None
    results: dict | None = None   # AnalysisResult serialised as dict when done
    error: str | None = None


class UploadUrlRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    match_id: str
    content_type: str = "video/mp4"
    content_length: int  # compressed file size in bytes


class UploadUrlResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    upload_url: str   # pre-signed PUT URL, valid for 1 hour
    object_key: str   # R2 key: "videos/{match_id}.mp4"
    expires_at: str   # ISO-8601 timestamp


class AnalyzeRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    match_id: str
    video_url: str


class CalibrationKeypointInput(BaseModel):
    """Single keypoint from Flutter calibration screen."""
    label: str          # e.g., "k1"
    x_px: float         # Pixel X coordinate
    y_px: float         # Pixel Y coordinate
    x_m: float          # Real-world court X (0–10m)
    y_m: float          # Real-world court Y (0–20m)


class CalibrationRequest(BaseModel):
    """Calibration data sent from Flutter app."""
    match_id: str
    keypoints: list[CalibrationKeypointInput | None]  # 12 items, some may be None
    frame_base64: str | None = None  # Optional: for debug visualization


class CalibrationResponse(BaseModel):
    """Response after processing calibration."""
    success: bool
    message: str
    homography_matrix: list[list[float]] | None = None  # 3×3 matrix if success
