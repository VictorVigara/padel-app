# CV Backend

Python FastAPI server for async match video analysis. Runs on a cloud GPU
(Modal, serverless A10G). Picks up jobs from a Supabase queue, downloads the
video from Cloudflare R2, runs the CV pipeline, writes results back to Supabase,
and deletes the video from R2.

---

## Setup

### Prerequisites

- Python 3.11
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- A Supabase project with migrations applied (see repo root README)
- A Cloudflare R2 bucket (see "R2 setup" below)

### Install dependencies

```bash
# From repo root — installs FastAPI, uvicorn, supabase-py, pydantic, python-dotenv
uv sync

# On GPU workers only — installs torch, ultralytics (YOLO), boxmot (Sprint 2+)
uv sync --extra cv
```

### Environment variables

```bash
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_SERVICE_KEY, and the Cloudflare R2 credentials
```

---

## Run locally

```bash
# From repo root
uv run uvicorn cv_backend.api.main:app --reload
```

The server starts at `http://localhost:8000`. In Sprint 0 the endpoints are stubs —
no real CV processing happens and no video is downloaded.

---

## API

### `POST /analyze`

Enqueue a match video for processing.

```
Body:   { "match_id": "<uuid>", "video_url": "<r2-object-url>" }
Returns: { "job_id": "<uuid>", "status": "queued" }
```

### `GET /analyze/{job_id}`

Poll job status.

```
Returns: {
  "status": "queued" | "processing" | "done" | "failed",
  "progress_pct": 0–100 | null,
  "results": { ...AnalysisResult... } | null,
  "error": "message" | null
}
```

---

## Cloudflare R2 setup

R2 is an S3-compatible object store with no egress fees — important because the
backend downloads large video files (~400–800 MB per match).

**Supabase Storage is NOT used for videos** — its 50 MB file size limit rules it out.

### Create a bucket

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → R2 → Create bucket
2. Name it `padel-match-videos` (or update `CLOUDFLARE_R2_BUCKET` in `.env`)
3. Leave public access OFF — videos are accessed via pre-signed URLs only

### Create an API token

1. R2 → Manage R2 API tokens → Create API token
2. Permissions: Object Read & Write
3. Scope: the `padel-match-videos` bucket only
4. Copy the Access Key ID and Secret Access Key into `.env`

### How the backend downloads from R2

R2 is S3-compatible. The backend uses `boto3` with a custom endpoint:

```python
import boto3, os

s3 = boto3.client(
    "s3",
    endpoint_url=f"https://{os.environ['CLOUDFLARE_R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
    aws_access_key_id=os.environ["CLOUDFLARE_R2_ACCESS_KEY"],
    aws_secret_access_key=os.environ["CLOUDFLARE_R2_SECRET_KEY"],
    region_name="auto",
)

# Download video to a local temp file before passing to analyze_match()
s3.download_file(
    Bucket=os.environ["CLOUDFLARE_R2_BUCKET"],
    Key=object_key,          # extracted from video_url in the processing_jobs row
    Filename="/tmp/match.mp4",
)

# After successful processing — delete to keep storage lean
s3.delete_object(Bucket=os.environ["CLOUDFLARE_R2_BUCKET"], Key=object_key)
```

`boto3` is added to `pyproject.toml` as a base dependency in Sprint 1 when the
download is actually implemented. In Sprint 0 the download step is a stub.

---

## Deploy to Modal

```bash
# Authenticate once
modal token set --token-id $MODAL_TOKEN_ID --token-secret $MODAL_TOKEN_SECRET

# Deploy
uv run modal deploy cv_backend/infra/modal_runner.py
```

CI/CD (`.github/workflows/deploy-backend.yml`) deploys automatically on every
push to `main` that touches `cv_backend/` or `pyproject.toml`.

---

## Architecture note — provider-agnostic pipeline

`cv_backend/pipeline/analyze_match.py` is the only contract between the CV code
and the infrastructure. It takes a **local file path** and returns an
`AnalysisResult` dataclass. It knows nothing about R2, Modal, queues, or HTTP.

Switching GPU providers (Modal → RunPod) means rewriting only
`cv_backend/infra/modal_runner.py`. The pipeline stays untouched.
