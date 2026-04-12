import 'package:camera/camera.dart';
import 'package:padel_app/features/recording/domain/models/court_detection_result.dart';

/// Lightweight Flutter-side court detection heuristic.
///
/// Analyzes a camera frame to decide if the angle looks like a padel court.
/// Uses YUV color analysis: padel courts are blue-green, so we check if
/// enough pixels have a blue-green chroma signature.
///
/// This is a stub — Sprint 2 will replace it with a real homography check
/// against the backend court_detector.py.
class CourtDetectionService {
  /// Minimum ratio of blue-green pixels to pass court detection.
  /// Kept low for Sprint 1 stub — real homography check replaces this in Sprint 2.
  static const double _greenRatioThreshold = 0.08;

  /// Analyze a single camera frame and return a detection result.
  CourtDetectionResult analyze(CameraImage frame) {
    // YUV420 format: planes[0]=Y, planes[1]=U (Cb), planes[2]=V (Cr)
    // On some Android devices the format may be BGRA8888; handle both.
    if (frame.format.group == ImageFormatGroup.yuv420) {
      return _analyzeYuv(frame);
    }
    // For BGRA or unknown formats fall back to "unknown" so we don't block recording.
    return const CourtDetectionResult(
      status: CourtDetectionStatus.unknown,
      message: 'Checking angle…',
    );
  }

  CourtDetectionResult _analyzeYuv(CameraImage frame) {
    final uPlane = frame.planes[1].bytes;
    final vPlane = frame.planes[2].bytes;

    // Sample every 12th chroma pixel to keep this fast on the main isolate.
    const step = 12;
    int greenCount = 0;
    int total = 0;

    for (int i = 0; i < uPlane.length && i < vPlane.length; i += step) {
      final u = uPlane[i]; // Cb: blue-difference
      final v = vPlane[i]; // Cr: red-difference
      // Padel court green/blue-green: low Cr (not red), moderate-low Cb
      // In YUV: u (Cb) roughly 85–130, v (Cr) < 120 for green hues
      if (u < 135 && v < 120) greenCount++;
      total++;
    }

    if (total == 0) {
      return const CourtDetectionResult(
        status: CourtDetectionStatus.unknown,
        message: 'Checking angle…',
      );
    }

    final ratio = greenCount / total;
    if (ratio >= _greenRatioThreshold) {
      return const CourtDetectionResult(
        status: CourtDetectionStatus.good,
        message: 'Angle looks good ✓',
      );
    }
    return const CourtDetectionResult(
      status: CourtDetectionStatus.adjust,
      message: 'Aim the camera at the court — more court surface needed',
    );
  }
}
