"""
Standalone test for player tracking pipeline.

Usage:
    python -m cv_backend.scripts.test_player_tracking --video <path> [--homography <json>]

Example:
    python -m cv_backend.scripts.test_player_tracking --video test.mp4 --homography H.json

Prerequisites:
    - Test video file
    - Optional: homography matrix JSON file (3x3 array)
"""
import sys
from pathlib import Path

# Allow running from project root
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from cv_backend.pipeline.analyze_match import analyze_match, AnalysisConfig


def main():
    import argparse
    import json

    parser = argparse.ArgumentParser(description="Test player tracking pipeline")
    parser.add_argument("--video", required=True, help="Path to test video")
    parser.add_argument("--homography", help="Path to H matrix JSON (required)")
    args = parser.parse_args()

    # Verify video exists
    video_path = Path(args.video)
    if not video_path.exists():
        print(f"Error: Video file not found: {video_path}")
        sys.exit(1)

    # Load H matrix (required)
    if not args.homography:
        print("Error: --homography is required. Provide path to 3x3 homography matrix JSON.")
        sys.exit(1)

    H_path = Path(args.homography)
    if not H_path.exists():
        print(f"Error: Homography file not found: {H_path}")
        sys.exit(1)

    with open(H_path) as f:
        H = json.load(f)

    # Run pipeline
    print(f"Processing {video_path}...")
    print(f"Using homography from {H_path}")
    print(f"{'='*50}")

    try:
        result = analyze_match(str(video_path), AnalysisConfig(), H)
    except Exception as exc:
        print(f"\n✗ Pipeline failed: {exc}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    # Print results
    print(f"\n{'='*50}")
    print(f"RESULTS")
    print(f"{'='*50}")
    print(f"Processed: {result.processing_meta.frames_processed} frames")
    print(f"Duration: {result.processing_meta.duration_s:.1f}s")
    print(f"Players tracked: {len(result.players)}")

    if result.processing_meta.warnings:
        print(f"\nWarnings:")
        for w in result.processing_meta.warnings:
            print(f"  - {w}")

    for p in result.players:
        print(f"\n{p.track_id}:")
        print(f"  Distance: {p.total_distance_m:.1f}m")
        print(f"  Coverage: {p.court_coverage_pct:.1f}%")
        print(f"  Positions: {len(p.positions)}")

    print(f"\n{'='*50}")
    print("✓ Test completed successfully")


if __name__ == "__main__":
    main()
