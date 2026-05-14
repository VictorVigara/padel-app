"""
Provider-agnostic CV pipeline interface.

CRITICAL CONSTRAINT: This function must never import or reference Modal,
RunPod, Supabase, queues, or HTTP. It takes a local file path and returns
a Python dataclass. Infrastructure concerns live entirely in infra/.

Switching GPU providers = rewriting only infra/modal_runner.py.
Nothing in this file ever changes for infrastructure reasons.
"""

from dataclasses import dataclass, field


@dataclass
class AnalysisConfig:
    """Configuration for match analysis pipeline."""

    player_count: int = 4
    fps_sample_rate: int = 1  # Process every Nth frame (1 = all frames, 10 = every 10th)
    # Rationale: stride=1 gives best tracking quality, but costs more GPU time.
    # For 90-min match at 30fps: 162k frames total.
    # stride=1 → 162k frames (~8-10 min GPU)
    # stride=10 → 16.2k frames (~1-2 min GPU, but tracking gaps)
    # Surfaced as config to make cost/quality tradeoff explicit.


@dataclass
class Position:
    t: float    # seconds from match start
    x: float    # metres from left baseline (court is 10m wide)
    y: float    # metres from sideline (court is 20m long)


@dataclass
class PlayerAnalysis:
    track_id: str
    total_distance_m: float
    court_coverage_pct: float
    heatmap: list[list[float]]  # 20×10 grid, values 0–1
    positions: list[Position]   # 1 position per second of match


@dataclass
class ProcessingMeta:
    duration_s: float           # wall-clock time to process
    frames_processed: int
    warnings: list[str] = field(default_factory=list)


@dataclass
class AnalysisResult:
    players: list[PlayerAnalysis]
    processing_meta: ProcessingMeta


def analyze_match(
    video_path: str,
    config: AnalysisConfig | None = None,
    homography_matrix: list[list[float]] | None = None,
) -> AnalysisResult:
    """
    Run the full CV pipeline on a match video.

    Args:
        video_path: Absolute path to the local video file. The caller
                    (infra layer) is responsible for downloading the video
                    before calling this function.
        config:     Analysis settings. Defaults to AnalysisConfig() if None.
        homography_matrix: 3×3 homography matrix for court projection.
                          REQUIRED in Sprint 2+ for meaningful distance/coverage.

    Returns:
        AnalysisResult with per-player heatmaps, distance, and positions.

    Raises:
        ValueError: If homography_matrix is missing or tracking fails.
    """
    import time
    import numpy as np
    from padeldet.player_tracker.player_tracker import PlayerTracker, PlayerTrackerConfig
    from padeldet.video import VideoInfo, frame_generator
    from padeldet.court.projection import CourtProjection

    start_time = time.time()

    if config is None:
        config = AnalysisConfig()

    # Homography is required for meaningful results
    if homography_matrix is None:
        raise ValueError("homography_matrix is required. Cannot compute distance/coverage without court projection.")

    # 1. Get video info
    video_info = VideoInfo.from_path(video_path)

    # 2. Initialize court projection
    court_projection = CourtProjection.from_matrix(np.array(homography_matrix))

    # 3. Initialize player tracker
    tracker_config = PlayerTrackerConfig(
        model_path="yolov8m.pt",
        confidence=0.1,
        iou_threshold=0.1,
        imgsz=960,
        batch_size=8,
        max_players=10,
        tracker_type="deepocsort",
        reid_weights="/tmp/osnet_x0_25_msmt17.pt",
        auto_select_players=True,
    )
    tracker = PlayerTracker(
        config=tracker_config,
        video_info=video_info,
        court_projection=court_projection,
    )

    # 4. Process video at configured sample rate
    stride = config.fps_sample_rate
    frames = frame_generator(video_path, stride=stride)
    results = tracker.detect_and_track(frames)

    # 5. Aggregate results
    analysis = _aggregate_tracking_results(
        results,
        court_projection,
        video_info,
        stride,
    )

    duration_s = time.time() - start_time
    analysis.processing_meta.duration_s = duration_s
    analysis.processing_meta.frames_processed = len(results)

    return analysis


def _aggregate_tracking_results(
    frame_detections: list,  # list[FrameDetections] from padeldet
    court_projection,  # CourtProjection
    video_info,  # VideoInfo from padeldet
    stride: int,
) -> AnalysisResult:
    """Convert tracking results to AnalysisResult format."""
    from collections import defaultdict
    import numpy as np

    # Group detections by logical_player_id (stable 1–4) when available, else track_id
    tracks: dict[int, list] = defaultdict(list)
    for fd in frame_detections:
        for det in fd.detections:
            player_key = det.logical_player_id if det.logical_player_id is not None else det.track_id
            if player_key is not None:
                tracks[player_key].append(det)

    warnings = []
    if len(tracks) == 0:
        warnings.append("No players detected")
    elif len(tracks) < 4:
        warnings.append(f"Only {len(tracks)} players tracked (expected 4)")

    players = []
    for track_id, detections in tracks.items():
        positions = []
        heatmap_grid = np.zeros((20, 10))  # 20m x 10m court, 1m cells

        for i, det in enumerate(detections):
            # Use pre-computed court_position when available (set by tracker with ankle midpoint)
            if det.court_position is not None:
                x_m, y_m = det.court_position
            else:
                foot_pos = det.ankle_midpoint if det.ankle_midpoint is not None else det.bbox.bottom_center
                x_m, y_m = court_projection.project_point(foot_pos)

            # Only count if inside court bounds
            if court_projection.is_inside_court((x_m, y_m)):
                # Time in seconds (e.g. stride=1, fps=30 → 30fps tracking → 0.033s per frame)
                t_s = i * stride / video_info.fps
                positions.append(Position(t=t_s, x=x_m, y=y_m))

                # Update heatmap (clamp to valid grid)
                grid_y = int(np.clip(y_m, 0, 19.99))
                grid_x = int(np.clip(x_m, 0, 9.99))
                heatmap_grid[grid_y, grid_x] += 1

        # Normalize heatmap to 0-1 range
        if heatmap_grid.max() > 0:
            heatmap_grid = heatmap_grid / heatmap_grid.max()

        # Compute total distance (Euclidean sum between consecutive positions)
        total_distance = 0.0
        if len(positions) > 1:
            for i in range(1, len(positions)):
                dx = positions[i].x - positions[i-1].x
                dy = positions[i].y - positions[i-1].y
                total_distance += np.sqrt(dx*dx + dy*dy)

        # Compute court coverage (% of 1m cells visited)
        cells_visited = np.count_nonzero(heatmap_grid)
        coverage_pct = (cells_visited / 200.0) * 100  # 200 cells total (20m × 10m grid)

        players.append(PlayerAnalysis(
            track_id=f"player_{track_id}",
            total_distance_m=total_distance,
            court_coverage_pct=coverage_pct,
            heatmap=heatmap_grid.tolist(),
            positions=positions,
        ))

    return AnalysisResult(
        players=players,
        processing_meta=ProcessingMeta(
            duration_s=0.0,  # Set by caller
            frames_processed=0,  # Set by caller
            warnings=warnings,
        ),
    )
