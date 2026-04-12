/// Result of the Flutter-side court detection heuristic.
enum CourtDetectionStatus { good, adjust, unknown }

class CourtDetectionResult {
  final CourtDetectionStatus status;
  final String message;

  const CourtDetectionResult({required this.status, required this.message});

  bool get isGood => status == CourtDetectionStatus.good;
}
