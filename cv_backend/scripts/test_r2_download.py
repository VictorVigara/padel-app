"""Test R2 download independently before integrating with tracking.

Usage:
    python -m cv_backend.scripts.test_r2_download <video_key>

Example:
    python -m cv_backend.scripts.test_r2_download videos/test.mp4

Prerequisites:
    - Upload a test video to R2 first
    - Set R2 credentials in environment (.env file or export)
"""
import os
import sys
import tempfile
import boto3
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()


def test_r2_download(key: str) -> None:
    """Test downloading a video from R2."""
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

    bucket = os.environ["CLOUDFLARE_R2_BUCKET"]

    print(f"Testing R2 download:")
    print(f"  Bucket: {bucket}")
    print(f"  Key: {key}")

    tmp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
    tmp_file.close()

    try:
        print(f"\nDownloading to {tmp_file.name}...")
        with open(tmp_file.name, 'wb') as f:
            s3_client.download_fileobj(bucket, key, f)

        size = Path(tmp_file.name).stat().st_size
        print(f"✓ Downloaded {size:,} bytes")

        # Verify video is valid
        import cv2
        cap = cv2.VideoCapture(tmp_file.name)
        if cap.isOpened():
            fps = cap.get(cv2.CAP_PROP_FPS)
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            print(f"✓ Video is valid (OpenCV can open it)")
            print(f"  Resolution: {width}x{height}")
            print(f"  FPS: {fps}")
            print(f"  Frames: {frames}")
            cap.release()
        else:
            print(f"✗ Video download corrupted (OpenCV cannot open it)")
            sys.exit(1)

    except Exception as exc:
        print(f"✗ Download failed: {exc}")
        sys.exit(1)
    finally:
        Path(tmp_file.name).unlink(missing_ok=True)
        print(f"\nCleaned up temp file")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python -m cv_backend.scripts.test_r2_download <video_key>")
        print("Example: python -m cv_backend.scripts.test_r2_download videos/test.mp4")
        sys.exit(1)

    test_r2_download(sys.argv[1])
