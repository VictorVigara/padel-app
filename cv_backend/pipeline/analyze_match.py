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
    fps_sample_rate: int = 10   # process every Nth frame (10fps sufficient)
    court_side: str = "auto"    # which end camera is on
    player_count: int = 4       # hard prior — always 4 in padel


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
        homography_matrix: Optional 3×3 homography matrix for court projection.
                          If None, analysis proceeds without court projection
                          (metrics will be limited or estimated).

    Returns:
        AnalysisResult with per-player heatmaps, distance, and positions.

    Raises:
        ValueError: If court detection fails or fewer than 3 players are
                    tracked for a sustained period.
    """
    if config is None:
        config = AnalysisConfig()

    # Convert H matrix to CourtProjection if provided
    court_projection = None
    if homography_matrix is not None:
        from cv_backend.pipeline.court_projection import CourtProjection
        court_projection = CourtProjection(homography_matrix)

    # --- Sprint 2 TODO: Replace stub with real pipeline ---
    # If court_projection is None, player tracking can still run but
    # metrics will be degraded (no heatmap, estimated distance)
    #
    # Example:
    #   tracks = player_tracker.track(video_path, config)
    #   if court_projection:
    #       positions = [court_projection.project_point(t.bbox.bottom_center) for t in tracks]
    #       heatmap = compute_heatmap(positions)
    #   else:
    #       heatmap = None  # or compute pixel-space heatmap

    # --- STUB: returns dummy data so the infra layer can be tested end-to-end ---
    # Replace this block in Sprint 2 with real pipeline calls:
    #   homography = court_detector.detect(video_path)
    #   tracks = player_tracker.track(video_path, homography, config)
    #   return _aggregate(tracks, config)

    dummy_heatmap = [[0.0] * 10 for _ in range(20)]
    dummy_positions = [Position(t=float(i), x=5.0, y=10.0) for i in range(5)]

    dummy_players = [
        PlayerAnalysis(
            track_id=f"player_{i}",
            total_distance_m=0.0,
            court_coverage_pct=0.0,
            heatmap=dummy_heatmap,
            positions=dummy_positions,
        )
        for i in range(config.player_count)
    ]

    return AnalysisResult(
        players=dummy_players,
        processing_meta=ProcessingMeta(
            duration_s=0.0,
            frames_processed=0,
            warnings=["STUB: no real CV processing performed"],
        ),
    )
