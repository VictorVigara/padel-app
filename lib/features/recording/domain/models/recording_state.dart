/// State machine states for the recording flow.
enum RecordingFlowState {
  idle,
  detectingCourt,
  readyToRecord,
  badAngle,
  recording,
  stopping,
  compressing,
  uploading,
  insertingJob,
  done,
  error,
}

/// Immutable state held by RecordingNotifier.
class RecordingState {
  final RecordingFlowState flowState;
  final String matchId;
  final int elapsedSeconds;
  final double compressionProgress; // 0.0–1.0
  final int uploadBytesUploaded;
  final int uploadTotalBytes;
  final String? courtResultMessage; // "Angle looks good ✓" or adjustment hint
  final bool courtOk;
  final String? videoPath; // set after recording stops
  final String? framePath; // JPEG extracted from raw video before compression
  final String? errorMessage;

  const RecordingState({
    required this.matchId,
    this.flowState = RecordingFlowState.idle,
    this.elapsedSeconds = 0,
    this.compressionProgress = 0.0,
    this.uploadBytesUploaded = 0,
    this.uploadTotalBytes = 0,
    this.courtResultMessage,
    this.courtOk = false,
    this.videoPath,
    this.framePath,
    this.errorMessage,
  });

  double get uploadProgressPct =>
      uploadTotalBytes > 0 ? uploadBytesUploaded / uploadTotalBytes : 0.0;

  RecordingState copyWith({
    RecordingFlowState? flowState,
    int? elapsedSeconds,
    double? compressionProgress,
    int? uploadBytesUploaded,
    int? uploadTotalBytes,
    String? courtResultMessage,
    bool? courtOk,
    String? videoPath,
    String? framePath,
    String? errorMessage,
  }) {
    return RecordingState(
      matchId: matchId,
      flowState: flowState ?? this.flowState,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      compressionProgress: compressionProgress ?? this.compressionProgress,
      uploadBytesUploaded: uploadBytesUploaded ?? this.uploadBytesUploaded,
      uploadTotalBytes: uploadTotalBytes ?? this.uploadTotalBytes,
      courtResultMessage: courtResultMessage ?? this.courtResultMessage,
      courtOk: courtOk ?? this.courtOk,
      videoPath: videoPath ?? this.videoPath,
      framePath: framePath ?? this.framePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
