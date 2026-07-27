"""
Isolated GPU benchmark for the CV pipeline on Modal.
No Supabase, no R2, no app required.

Usage
-----
Small clip (<200 MB) — bytes are sent over the network:
  modal run cv_backend/scripts/test_modal_gpu.py --video /path/to/clip.mp4

Large video — upload once to a Modal Volume, then reference by name:
  modal volume create padel-test-videos
  modal volume put padel-test-videos /path/to/video.mp4 test.mp4
  modal run cv_backend/scripts/test_modal_gpu.py --volume-path test.mp4

Supply a real homography JSON (3×3 array) for meaningful distance stats:
  modal run cv_backend/scripts/test_modal_gpu.py --video clip.mp4 --homography H.json

Without --homography a passthrough identity-scale matrix is used so the
pipeline runs end-to-end but player court positions will be wrong.

GPU options (default A10G):
  modal run cv_backend/scripts/test_modal_gpu.py --video clip.mp4 --gpu T4
  modal run cv_backend/scripts/test_modal_gpu.py --video clip.mp4 --gpu A100

Detector backend (default rfdetr; padeldet's PlayerTrackerConfig default):
  modal run cv_backend/scripts/test_modal_gpu.py --video clip.mp4 --detector yolo
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import modal

# ---------------------------------------------------------------------------
# Modal image — CV deps only (no Supabase/boto3; this script talks to neither).
# Pulled from padeldet's own requirements.txt, the canonical CV dependency set —
# also keeps this image conflict-free (e.g. boxmot>=22 needs rich>=15, which
# collides with supabase's pyiceberg<15 pin if both end up in one image).
# ---------------------------------------------------------------------------

_REQUIREMENTS = str(
    Path(__file__).parent.parent.parent.parent / "padeldet" / "requirements.txt"
)

image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("libgl1-mesa-glx", "libglib2.0-0")
    .pip_install_from_requirements(_REQUIREMENTS)
    .add_local_python_source(
        "padeldet",
        ignore=["**/__pycache__", "**/*.pyc", "**/*.pyo", "**/.venv/**", "**/*.pt", "**/data/**"],
    )
    .add_local_python_source(
        "cv_backend",
        ignore=["**/__pycache__", "**/*.pyc", "**/*.pyo", "scripts/", "infra/", ".venv/"],
    )
)

app = modal.App("padel-cv-gpu-bench")

test_videos = modal.Volume.from_name("padel-test-videos", create_if_missing=True)

# ---------------------------------------------------------------------------
# Dummy homography: maps a 1920×1080 frame linearly to the 10 m × 20 m court.
# Detections will land inside court bounds so the tracker doesn't filter them.
# ---------------------------------------------------------------------------
_DUMMY_H: list[list[float]] = [
    [10.0 / 1920, 0.0,          0.0],
    [0.0,         20.0 / 1080,  0.0],
    [0.0,         0.0,          1.0],
]


# ---------------------------------------------------------------------------
# Remote function
# ---------------------------------------------------------------------------

GPU_TYPE = "T4"  # Change to A10G or A100 to benchmark different GPUs


@app.function(
    image=image,
    gpu=GPU_TYPE,
    timeout=300,
    volumes={"/videos": test_videos},
)
def get_selection_frame(
    video_bytes: bytes | None,
    volume_path: str | None,
    homography: list[list[float]],
    fps_sample_rate: int,
    keypoints: dict | None = None,
    detector: str = "rfdetr",
    tracker_type: str = "bytetrack",
) -> bytes:
    """Process the selection window, return the best frame annotated with track IDs as JPEG."""
    import tempfile
    from pathlib import Path as _Path

    import cv2
    import numpy as np

    from padeldet.player_tracker.player_tracker import PlayerTracker, PlayerTrackerConfig
    from padeldet.match_profile import MATCH_PROFILES
    from padeldet.video import VideoInfo, frame_generator
    from padeldet.court.projection import CourtProjection
    from padeldet.court.models import CourtKeypoints

    if video_bytes is not None:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        tmp.write(video_bytes)
        tmp.close()
        video_path = tmp.name
    elif volume_path is not None:
        video_path = f"/videos/{volume_path}"
    else:
        raise ValueError("Provide either video_bytes or volume_path.")

    video_info = VideoInfo.from_path(video_path)
    profile = MATCH_PROFILES["doubles"]
    if keypoints is not None:
        court_projection = CourtProjection(
            CourtKeypoints.from_dict(keypoints),
            width_m=profile.court.width_m,
            length_m=profile.court.length_m,
        )
    else:
        court_projection = CourtProjection.from_matrix(
            np.array(homography), width_m=profile.court.width_m, length_m=profile.court.length_m
        )

    tracker_config = PlayerTrackerConfig(
        detector_type=detector,
        model_path="yolo26m.pt",
        confidence=0.1,
        iou_threshold=0.1,
        imgsz=960,
        batch_size=8,
        tracker_type=tracker_type,
        reid_weights="/tmp/osnet_x0_25_msmt17.pt",
        auto_select_players=True,
    )
    tracker = PlayerTracker(config=tracker_config, video_info=video_info, court_projection=court_projection)

    fps = video_info.fps
    n_sel = max(30, int(tracker_config.selection_window_sec * fps / fps_sample_rate))
    frames = list(frame_generator(video_path, stride=fps_sample_rate, end_frame=n_sel * fps_sample_rate))
    init_indices = [i * fps_sample_rate for i in range(len(frames))]
    init_results = tracker._run_frames(frames, init_indices, desc="selection window")

    best_frame, best_fd = tracker._best_selection_frame(init_results, frames)

    # Draw all tracked detections with their track IDs so user can identify the 4 players
    img = best_frame.copy()
    for det in best_fd.detections:
        if det.track_id is None:
            continue
        x1, y1, x2, y2 = int(det.bbox.x1), int(det.bbox.y1), int(det.bbox.x2), int(det.bbox.y2)
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
        label = f"tid={det.track_id}"
        if det.court_position:
            label += f" ({det.court_position[0]:.1f},{det.court_position[1]:.1f}m)"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(img, (x1, y1 - th - 8), (x1 + tw + 4, y1), (0, 255, 0), -1)
        cv2.putText(img, label, (x1 + 2, y1 - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2, cv2.LINE_AA)

    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 92])
    return buf.tobytes() if ok else b""


@app.function(
    image=image,
    gpu=GPU_TYPE,
    timeout=1800,        # 30 min — enough for a full 90-min match at stride=1
    volumes={"/videos": test_videos},
)
def run_pipeline(
    video_bytes: bytes | None,
    volume_path: str | None,
    homography: list[list[float]],
    fps_sample_rate: int,
    keypoints: dict | None = None,
    detector: str = "rfdetr",
    tracker_type: str = "bytetrack",
    debug_overlay: bool = False,
    max_frames: int = 0,
) -> dict:
    """Run the tracker once; return stats, heatmap PNGs, and annotated video."""
    import logging
    import tempfile
    import time
    from collections import defaultdict
    from pathlib import Path as _Path

    import cv2
    import numpy as np

    from padeldet.player_tracker.player_tracker import PlayerTracker, PlayerTrackerConfig
    from padeldet.match_profile import MATCH_PROFILES
    from padeldet.video import VideoInfo, frame_generator
    from padeldet.court.projection import CourtProjection, draw_mini_court
    from padeldet.court.models import CourtKeypoints

    # ── resolve video path ──────────────────────────────────────────────────
    if video_bytes is not None:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        tmp.write(video_bytes)
        tmp.close()
        video_path = tmp.name
    elif volume_path is not None:
        video_path = f"/videos/{volume_path}"
        if not _Path(video_path).exists():
            raise FileNotFoundError(
                f"{volume_path} not found in Modal Volume. "
                "Upload with: modal volume put padel-test-videos <local.mp4> <name.mp4>"
            )
    else:
        raise ValueError("Provide either video_bytes or volume_path.")

    # ── init components ─────────────────────────────────────────────────────
    video_info = VideoInfo.from_path(video_path)
    profile = MATCH_PROFILES["doubles"]
    if keypoints is not None:
        court_projection = CourtProjection(
            CourtKeypoints.from_dict(keypoints),
            width_m=profile.court.width_m,
            length_m=profile.court.length_m,
        )
    else:
        court_projection = CourtProjection.from_matrix(
            np.array(homography), width_m=profile.court.width_m, length_m=profile.court.length_m
        )

    tracker_config = PlayerTrackerConfig(
        detector_type=detector,
        model_path="yolov8m.pt",
        confidence=0.1,
        iou_threshold=0.1,
        imgsz=960,
        batch_size=8,
        max_players=10,
        tracker_type=tracker_type,
        reid_weights="/tmp/osnet_x0_25_msmt17.pt",
        auto_select_players=True,
    )
    tracker = PlayerTracker(
        config=tracker_config,
        video_info=video_info,
        court_projection=court_projection,
    )

    # ── single tracking pass ────────────────────────────────────────────────
    # Capture the identity manager's per-frame [frame N] decision logs so they
    # can be drawn on the annotated video (--debug-overlay). Those records are
    # emitted at DEBUG/INFO; raise the root level to DEBUG while tracking.
    log_capture = None
    prev_level = logging.getLogger().level
    if debug_overlay:
        from padeldet.player_tracker.debug_overlay import FrameLogCapture
        log_capture = FrameLogCapture(level=logging.DEBUG)
        logging.getLogger().setLevel(logging.DEBUG)
        logging.getLogger().addHandler(log_capture)

    start_time = time.time()
    frames = list(frame_generator(video_path, stride=fps_sample_rate))
    if max_frames > 0:
        frames = frames[:max_frames]  # short-run cap for fast iteration
    try:
        frame_detections = tracker.detect_and_track(iter(frames))
    finally:
        if log_capture is not None:
            logging.getLogger().removeHandler(log_capture)
            logging.getLogger().setLevel(prev_level)
    duration_s = time.time() - start_time

    # ── annotated video ─────────────────────────────────────────────────────
    debug_lines = dict(log_capture.by_frame) if log_capture is not None else None
    annotated_video_bytes = _render_annotated_video(
        frames, frame_detections, court_projection, video_info, fps_sample_rate,
        debug_lines=debug_lines,
    )

    # ── aggregate stats ─────────────────────────────────────────────────────
    tracks: dict[int, list] = defaultdict(list)
    for fd in frame_detections:
        for det in fd.detections:
            key = det.logical_player_id if det.logical_player_id is not None else det.track_id
            if key is not None:
                tracks[key].append(det)

    warnings = []
    if not tracks:
        warnings.append("No players detected")
    elif len(tracks) < 4:
        warnings.append(f"Only {len(tracks)} players tracked (expected 4)")

    cell_size_m = 1.0
    grid_rows = int(profile.court.length_m / cell_size_m)
    grid_cols = int(profile.court.width_m / cell_size_m)
    half_cells = int((profile.court.length_m / 2) / cell_size_m) * grid_cols

    players_out = []
    heatmap_pngs: dict[str, bytes] = {}
    for player_key, detections in tracks.items():
        heatmap_grid = np.zeros((grid_rows, grid_cols))
        positions_count = 0
        total_distance = 0.0
        prev_pos = None

        for det in detections:
            if det.court_position is not None:
                x_m, y_m = det.court_position
            else:
                foot = det.ankle_midpoint or det.bbox.bottom_center
                x_m, y_m = court_projection.project_point(foot)

            if court_projection.is_inside_court((x_m, y_m)):
                positions_count += 1
                gy = int(np.clip(y_m / cell_size_m, 0, grid_rows - 0.01))
                gx = int(np.clip(x_m / cell_size_m, 0, grid_cols - 0.01))
                heatmap_grid[gy, gx] += 1
                if prev_pos is not None:
                    dx, dy = x_m - prev_pos[0], y_m - prev_pos[1]
                    total_distance += np.sqrt(dx * dx + dy * dy)
                prev_pos = (x_m, y_m)

        if heatmap_grid.max() > 0:
            heatmap_grid /= heatmap_grid.max()

        cells_visited = int(np.count_nonzero(heatmap_grid))
        coverage_pct = cells_visited / half_cells * 100

        pid = str(player_key)
        players_out.append({
            "track_id": pid,
            "distance_m": round(total_distance, 1),
            "coverage_pct": round(coverage_pct, 1),
            "positions": positions_count,
        })
        heatmap_pngs[pid] = _render_heatmap_png(pid, heatmap_grid.tolist())

    fps_speed = len(frames) / duration_s if duration_s > 0 else 0

    return {
        "duration_s": round(duration_s, 2),
        "frames_processed": len(frames),
        "fps_speed": round(fps_speed, 1),
        "players_detected": len(tracks),
        "fps_sample_rate": fps_sample_rate,
        "warnings": warnings,
        "players": players_out,
        "heatmap_pngs": heatmap_pngs,
        "annotated_video": annotated_video_bytes,
    }


# Player colours per logical ID (BGR)
_PLAYER_COLORS_BGR = [
    (0,   200,  50),   # P1 green
    (0,   140, 255),   # P2 orange
    (255,  80,  80),   # P3 blue
    (180,   0, 255),   # P4 pink
    (200, 200,   0),   # P5+
]


def _render_annotated_video(
    frames: list,
    frame_detections: list,
    court_projection,
    video_info,
    stride: int,
    debug_lines: dict | None = None,
) -> bytes:
    """Draw bounding boxes, ankle dots, player IDs, and mini-court on each frame.

    If `debug_lines` is given (a {frame_index: [str, ...]} map captured from the
    identity manager's per-frame `[frame N]` log records), those decision lines
    are drawn in the top-left corner so the reassignment reasoning is visible.
    """
    import cv2
    import tempfile
    from padeldet.court.projection import draw_mini_court
    from padeldet.player_tracker.debug_overlay import draw_log_overlay

    fd_map = {fd.frame_index: fd for fd in frame_detections}
    h, w = frames[0].shape[:2]
    out_fps = max(1.0, video_info.fps / stride)

    tmp = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
    writer = cv2.VideoWriter(
        tmp.name, cv2.VideoWriter_fourcc(*"mp4v"), out_fps, (w, h)
    )

    for i, frame in enumerate(frames):
        img = frame.copy()
        # `frames` is the already-subsampled list handed to detect_and_track(),
        # which assigns frame_index = 0,1,2,… (start_frame=0, stride=1 defaults).
        # So the render list is 1:1 with frame_detections — index directly by i.
        # (Multiplying by the sampling stride here mismatched the keys, leaving
        # most frames unannotated and the rest showing the wrong frame's boxes.)
        fd = fd_map.get(i)

        if fd is not None:
            for det in fd.detections:
                pid = det.logical_player_id or det.track_id or 0
                color = _PLAYER_COLORS_BGR[(pid - 1) % len(_PLAYER_COLORS_BGR)]

                # Bounding box
                x1, y1, x2, y2 = (
                    int(det.bbox.x1), int(det.bbox.y1),
                    int(det.bbox.x2), int(det.bbox.y2),
                )
                cv2.rectangle(img, (x1, y1), (x2, y2), color, 2)

                # Label: P<id>
                label = f"P{pid}"
                (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
                cv2.rectangle(img, (x1, y1 - th - 6), (x1 + tw + 4, y1), color, -1)
                cv2.putText(img, label, (x1 + 2, y1 - 3),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2, cv2.LINE_AA)

                # Ankle midpoint dot
                if det.ankle_midpoint is not None:
                    ax, ay = int(det.ankle_midpoint[0]), int(det.ankle_midpoint[1])
                    cv2.circle(img, (ax, ay), 6, (0, 255, 255), -1)
                    cv2.circle(img, (ax, ay), 6, (0, 0, 0), 1)

            # Mini-court overlay (bottom-right corner)
            draw_mini_court(img, court_projection, fd)

        # Identity-manager decision log for this frame (top-left corner).
        if debug_lines is not None:
            draw_log_overlay(img, debug_lines.get(i, []))

        writer.write(img)

    writer.release()
    import pathlib
    data = pathlib.Path(tmp.name).read_bytes()
    pathlib.Path(tmp.name).unlink(missing_ok=True)
    return data


def _render_heatmap_png(player_id: str, heatmap: list[list[float]]) -> bytes:
    """Render a 20×10 heatmap grid as a colour-coded PNG (bytes)."""
    import cv2
    import numpy as np

    grid = np.array(heatmap, dtype=np.float32)  # (20, 10)

    # Scale to 0-255 and apply blue→red colormap
    heat_u8 = (grid * 255).astype(np.uint8)
    coloured = cv2.applyColorMap(heat_u8, cv2.COLORMAP_JET)

    # Upscale for readability: each 1m cell → 40px
    cell = 40
    img = cv2.resize(coloured, (10 * cell, 20 * cell), interpolation=cv2.INTER_NEAREST)

    # Draw grid lines
    for x in range(0, 10 * cell + 1, cell):
        cv2.line(img, (x, 0), (x, 20 * cell), (80, 80, 80), 1)
    for y in range(0, 20 * cell + 1, cell):
        cv2.line(img, (0, y), (10 * cell, y), (80, 80, 80), 1)

    # Net line at y=10m (row 10 in grid = pixel row 10*cell)
    net_y = 10 * cell
    cv2.line(img, (0, net_y), (10 * cell, net_y), (255, 255, 255), 2)

    # Label
    cv2.putText(img, f"Player {player_id}", (8, 24),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2, cv2.LINE_AA)

    ok, buf = cv2.imencode(".png", img)
    return buf.tobytes() if ok else b""


# ---------------------------------------------------------------------------
# Local entrypoint
# ---------------------------------------------------------------------------

@app.local_entrypoint()
def main(
    video: str = "",
    volume_path: str = "",
    homography: str = "",
    keypoints: str = "",
    stride: int = 1,
    get_selection_frame: bool = False,
    detector: str = "rfdetr",
    tracker_type: str = "bytetrack",
    debug_overlay: bool = False,
    max_frames: int = 0,
):
    """
    Parameters
    ----------
    video                : local path to video file (bytes sent over network)
    volume_path          : filename inside the padel-test-videos Modal Volume
    homography           : local path to a JSON file containing a 3×3 H matrix
    keypoints            : local path to a court_keypoints.json file (auto-detected
                           from the video's directory if not supplied)
    stride               : fps_sample_rate — 1 = every frame, 5 = every 5th frame
    get_selection_frame  : download the best selection frame to output/selection_frame.jpg
    detector             : "rfdetr" (default) or "yolo"
    tracker_type         : "bytetrack" (default) or "deepocsort" (OSNet ReID)
    debug_overlay        : draw the identity manager's per-frame [frame N] decision
                           logs (direct_track_id / same_role / proximity / side-change
                           gate / state snapshot) onto the annotated video

    To change GPU: edit GPU_TYPE at the top of this file (T4 | A10G | A100).
    """
    if not video and not volume_path:
        print("ERROR: provide --video <path> or --volume-path <name>")
        sys.exit(1)

    # Read local video bytes if needed
    video_bytes: bytes | None = None
    if video:
        p = Path(video)
        if not p.exists():
            print(f"ERROR: video file not found: {p}")
            sys.exit(1)
        size_mb = p.stat().st_size / 1_000_000
        if size_mb > 500:
            print(
                f"WARNING: {size_mb:.0f} MB is large to transfer as bytes.\n"
                "Consider uploading to a Modal Volume instead:\n"
                f"  modal volume put padel-test-videos {video} <name>.mp4\n"
                "  modal run ... --volume-path <name>.mp4"
            )
        print(f"Reading {p.name} ({size_mb:.1f} MB)...")
        video_bytes = p.read_bytes()

    # Resolve court keypoints / homography
    kp_dict: dict | None = None
    H: list[list[float]] = _DUMMY_H
    h_source = "dummy (identity-scale, positions not meaningful)"

    if keypoints:
        kp_path = Path(keypoints)
        if not kp_path.exists():
            print(f"ERROR: keypoints file not found: {kp_path}")
            sys.exit(1)
        kp_dict = json.loads(kp_path.read_text())
        h_source = kp_path.name
    elif video:
        auto = Path(video).parent / "court_keypoints.json"
        if auto.exists():
            kp_dict = json.loads(auto.read_text())
            h_source = str(auto)
            print(f"Auto-loaded keypoints: {auto}")
    if kp_dict is None and homography:
        H = json.loads(Path(homography).read_text())
        h_source = Path(homography).name

    out_dir = Path(__file__).parent / "output"
    out_dir.mkdir(exist_ok=True)

    # ── Mode 1: get selection frame only ────────────────────────────────────
    if get_selection_frame:
        print(f"\n--- Fetching selection frame (GPU: {GPU_TYPE}, stride: {stride}) ---")
        print("Sending to Modal...")
        jpg_bytes = get_selection_frame.remote(
            video_bytes=video_bytes,
            volume_path=volume_path or None,
            homography=H,
            fps_sample_rate=stride,
            keypoints=kp_dict,
            detector=detector,
            tracker_type=tracker_type,
        )
        out_path = out_dir / "selection_frame.jpg"
        out_path.write_bytes(jpg_bytes)
        print(f"\nSaved → {out_path}")
        return

    # ── Mode 2: full pipeline ───────────────────────────────────────────────
    print(f"\n--- Modal GPU Benchmark ---")
    print(f"GPU:         {GPU_TYPE}")
    print(f"Detector:    {detector}")
    print(f"Tracker:     {tracker_type}")
    print(f"Stride:      {stride} (every {stride} frame(s))")
    print(f"Homography:  {h_source}")
    print(f"Source:      {video or volume_path}")
    print("Sending to Modal...\n")

    result = run_pipeline.remote(
        video_bytes=video_bytes,
        volume_path=volume_path or None,
        homography=H,
        fps_sample_rate=stride,
        keypoints=kp_dict,
        detector=detector,
        tracker_type=tracker_type,
        debug_overlay=debug_overlay,
        max_frames=max_frames,
    )

    # Print results
    print("=== RESULTS ===")
    print(f"GPU:              {GPU_TYPE}")
    print(f"Stride:           {result['fps_sample_rate']}")
    print(f"Frames processed: {result['frames_processed']}")
    print(f"Wall-clock time:  {result['duration_s']}s")
    print(f"Throughput:       {result['fps_speed']} frames/sec")
    print(f"Players detected: {result['players_detected']}")

    if result["warnings"]:
        print(f"\nWarnings:")
        for w in result["warnings"]:
            print(f"  - {w}")

    if result["players"]:
        print(f"\nPer-player stats:")
        for p in result["players"]:
            print(
                f"  {p['track_id']}: {p['distance_m']}m  "
                f"coverage={p['coverage_pct']}%  positions={p['positions']}"
            )

    # Save heatmap PNGs
    pngs = result.get("heatmap_pngs", {})
    if pngs:
        print(f"\nHeatmaps → {out_dir}/")
        for player_id, png_bytes in pngs.items():
            if png_bytes:
                out_path = out_dir / f"heatmap_{player_id}.png"
                out_path.write_bytes(png_bytes)
                print(f"  {out_path.name}")

    # Save annotated video
    vid_bytes = result.get("annotated_video", b"")
    if vid_bytes:
        vid_path = out_dir / "annotated.mp4"
        vid_path.write_bytes(vid_bytes)
        size_mb = len(vid_bytes) / 1_000_000
        print(f"\nAnnotated video → {vid_path}  ({size_mb:.1f} MB)")

    print("\nDone.")
