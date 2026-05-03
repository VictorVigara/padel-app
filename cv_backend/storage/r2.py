"""
Cloudflare R2 helpers (S3-compatible).

Single source of truth for R2 client construction, presigned URL generation,
video download, and cleanup. All env var reads happen inside functions so this
module is safe to import in CPU-only contexts without requiring credentials at
import time.
"""
from __future__ import annotations

import os

import boto3
from botocore.config import Config


def get_r2_client():
    """Return a boto3 S3 client configured for Cloudflare R2."""
    account_id = os.environ["CLOUDFLARE_R2_ACCOUNT_ID"]
    return boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=os.environ["CLOUDFLARE_R2_ACCESS_KEY"],
        aws_secret_access_key=os.environ["CLOUDFLARE_R2_SECRET_KEY"],
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


def generate_presigned_upload_url(
    object_key: str,
    content_type: str,
    content_length: int,
    expires_in: int = 3600,
) -> str:
    """Generate a presigned PUT URL for direct client upload to R2."""
    bucket = os.environ["CLOUDFLARE_R2_BUCKET"]
    return get_r2_client().generate_presigned_url(
        "put_object",
        Params={
            "Bucket": bucket,
            "Key": object_key,
            "ContentType": content_type,
            "ContentLength": content_length,
        },
        ExpiresIn=expires_in,
    )


def extract_object_key(video_url: str, bucket: str) -> str:
    """
    Extract the S3 object key from a full R2 URL.

    Handles:
      https://<account>.r2.cloudflarestorage.com/<bucket>/videos/123.mp4
      → "videos/123.mp4"
    """
    if f"/{bucket}/" in video_url:
        return video_url.split(f"/{bucket}/", 1)[1]
    parts = video_url.split("/")
    return "/".join(parts[4:]) if len(parts) > 4 else parts[-1]


def download_from_r2(s3_client, bucket: str, object_key: str, local_path: str) -> None:
    """Download an R2 object to a local file path."""
    with open(local_path, "wb") as f:
        s3_client.download_fileobj(bucket, object_key, f)


def delete_from_r2(s3_client, bucket: str, object_key: str) -> None:
    """Delete an object from R2. Callers should handle exceptions themselves."""
    s3_client.delete_object(Bucket=bucket, Key=object_key)
