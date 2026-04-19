"""Homography-based court projection utilities."""

from __future__ import annotations
import numpy as np
import cv2

# Standard padel court dimensions (metres)
COURT_WIDTH = 10.0
COURT_LENGTH = 20.0
NET_POSITION = 10.0
SERVICE_BOX_DEPTH = 3.0

# 12-point standard court keypoints (x, y) in metres
COURT_KEYPOINTS_2D = [
    (0.0, 0.0),      # k1: near baseline left
    (10.0, 0.0),     # k2: near baseline right
    (0.0, 3.0),      # k3: near service line left
    (5.0, 3.0),      # k4: near service line center
    (10.0, 3.0),     # k5: near service line right
    (0.0, 10.0),     # k6: net left
    (10.0, 10.0),    # k7: net right
    (0.0, 17.0),     # k8: far service line left
    (5.0, 17.0),     # k9: far service line center
    (10.0, 17.0),    # k10: far service line right
    (0.0, 20.0),     # k11: far baseline left
    (10.0, 20.0),    # k12: far baseline right
]


def compute_homography(
    keypoints_pixel: list[tuple[float, float]],
    keypoint_indices: list[int],
    ransac_threshold: float = 5.0,
) -> np.ndarray:
    """
    Compute homography matrix from pixel keypoints to court metres.

    Args:
        keypoints_pixel: List of (x_px, y_px) tuples for non-null keypoints.
        keypoint_indices: Original indices (0-11) indicating which keypoints
                         in COURT_KEYPOINTS_2D these correspond to. Must have
                         the same length as keypoints_pixel.
        ransac_threshold: RANSAC reprojection threshold in pixels. Lower values
                         are stricter. May need tuning based on video resolution
                         and camera perspective (default 5.0 is a starting point).

    Returns:
        3×3 homography matrix (numpy array).

    Raises:
        ValueError: If fewer than 4 keypoints, mismatched lengths, or RANSAC fails.
    """
    if len(keypoints_pixel) < 4:
        raise ValueError(
            f"Need at least 4 keypoints for homography, got {len(keypoints_pixel)}"
        )

    if len(keypoints_pixel) != len(keypoint_indices):
        raise ValueError(
            f"Mismatched lengths: {len(keypoints_pixel)} pixels vs {len(keypoint_indices)} indices"
        )

    # Extract corresponding court coordinates using the ORIGINAL indices
    court_pts = [COURT_KEYPOINTS_2D[idx] for idx in keypoint_indices]

    src = np.array(keypoints_pixel, dtype=np.float64)
    dst = np.array(court_pts, dtype=np.float64)

    H, mask = cv2.findHomography(src, dst, cv2.RANSAC, ransac_threshold)

    if H is None:
        raise ValueError(
            "Could not compute homography — RANSAC failed. Check keypoint quality."
        )

    return H


class CourtProjection:
    """Projects pixel coordinates to real court coordinates via homography."""

    def __init__(self, H: np.ndarray, margin_meters: float = 0.5):
        """
        Initialize with a precomputed homography matrix.

        Args:
            H: 3×3 homography matrix (numpy array or list of lists)
            margin_meters: Safety margin for court boundary checks
        """
        if isinstance(H, list):
            H = np.array(H, dtype=np.float64)

        if H.shape != (3, 3):
            raise ValueError(f"Homography must be 3×3, got {H.shape}")

        self._H = H
        self.margin = margin_meters

    def project_point(self, pixel_xy: tuple[float, float]) -> tuple[float, float]:
        """Project a pixel coordinate to court metres."""
        pt = np.array([pixel_xy[0], pixel_xy[1], 1.0], dtype=np.float64)
        result = self._H @ pt
        result = result / result[2]  # Normalize homogeneous coordinate
        return (float(result[0]), float(result[1]))

    def is_inside_court(self, court_xy: tuple[float, float]) -> bool:
        """Check if a court-metre point is inside the court (with margin)."""
        x, y = court_xy
        return (
            -self.margin <= x <= COURT_WIDTH + self.margin
            and -self.margin <= y <= COURT_LENGTH + self.margin
        )

    @property
    def homography(self) -> np.ndarray:
        """Return the homography matrix."""
        return self._H
