import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/recording/data/repositories/recording_repository.dart';
import 'package:padel_app/features/recording/domain/models/recording_state.dart';
import 'package:padel_app/features/recording/domain/services/compression_service.dart';
import 'package:padel_app/features/recording/domain/models/court_detection_result.dart';
import 'package:padel_app/features/recording/domain/services/court_detection_service.dart';
import 'package:path_provider/path_provider.dart';

/// Drives the full recording state machine.
///
/// Owns RecordingRepository, CourtDetectionService, and CompressionService.
/// Call [initialize] from initState of RecordingScreen.
class RecordingNotifier extends StateNotifier<RecordingState> {
  final RecordingRepository _repo;
  final CourtDetectionService _courtDetection;
  final CompressionService _compression;

  Timer? _elapsedTimer;
  Timer? _courtCheckTimer;
  DateTime? _recordingStartTime;

  RecordingNotifier({required String matchId})
      : _repo = RecordingRepository(),
        _courtDetection = CourtDetectionService(),
        _compression = CompressionService(),
        super(RecordingState(matchId: matchId));

  CameraController? get cameraController => _repo.controller;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      await _repo.initialize();
      state = state.copyWith(flowState: RecordingFlowState.detectingCourt);
      _startCourtDetection();
    } catch (e) {
      state = state.copyWith(
        flowState: RecordingFlowState.error,
        errorMessage: 'Could not open camera: $e',
      );
    }
  }

  // ── Court detection ────────────────────────────────────────────────────────

  void _startCourtDetection() {
    _repo.startImageStream(_onCameraFrame);
    // Re-evaluate periodically in case the user moves the phone.
    _courtCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // The stream callback updates state; this timer is a safety net.
    });
  }

  void _onCameraFrame(CameraImage frame) {
    if (state.flowState != RecordingFlowState.detectingCourt &&
        state.flowState != RecordingFlowState.readyToRecord &&
        state.flowState != RecordingFlowState.badAngle) {
      return;
    }
    final result = _courtDetection.analyze(frame);
    if (result.isGood) {
      if (state.flowState != RecordingFlowState.readyToRecord) {
        state = state.copyWith(
          flowState: RecordingFlowState.readyToRecord,
          courtOk: true,
          courtResultMessage: result.message,
        );
      }
    } else if (result.status == CourtDetectionStatus.adjust) {
      if (state.flowState != RecordingFlowState.badAngle) {
        state = state.copyWith(
          flowState: RecordingFlowState.badAngle,
          courtOk: false,
          courtResultMessage: result.message,
        );
      }
    } else {
      state = state.copyWith(courtResultMessage: result.message);
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> startRecording() async {
    if (state.flowState != RecordingFlowState.readyToRecord &&
        state.flowState != RecordingFlowState.badAngle &&
        state.flowState != RecordingFlowState.detectingCourt) return;

    // Must stop image stream before recording on most devices.
    await _repo.stopImageStream();
    _courtCheckTimer?.cancel();

    try {
      await _repo.startRecording();
      _recordingStartTime = DateTime.now();
      state = state.copyWith(
        flowState: RecordingFlowState.recording,
        elapsedSeconds: 0,
      );
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      });
    } catch (e) {
      state = state.copyWith(
        flowState: RecordingFlowState.error,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  Future<void> stopRecording() async {
    if (state.flowState != RecordingFlowState.recording) return;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    state = state.copyWith(flowState: RecordingFlowState.stopping);

    try {
      final rawPath = await _repo.stopRecording();

      // Extract a frame from the raw video before compression starts.
      final tmpDir = await getTemporaryDirectory();
      final framePath = '${tmpDir.path}/frame_${state.matchId}.jpg';
      try {
        await _compression.extractFrame(
          inputPath: rawPath,
          outputPath: framePath,
        );
        state = state.copyWith(framePath: framePath);
      } catch (_) {
        // Non-fatal — calibration screen handles null framePath gracefully.
      }

      state = state.copyWith(
        flowState: RecordingFlowState.compressing,
        videoPath: rawPath,
        compressionProgress: 0.0,
      );
      await _compressVideo(rawPath);
    } catch (e) {
      state = state.copyWith(
        flowState: RecordingFlowState.error,
        errorMessage: 'Failed to stop recording: $e',
      );
    }
  }

  // ── Compression ────────────────────────────────────────────────────────────

  Future<void> _compressVideo(String rawPath) async {
    final tmpDir = await getTemporaryDirectory();
    final outputPath = '${tmpDir.path}/compressed_${state.matchId}.mp4';
    final durationMs = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
        : 0;

    try {
      await for (final progress in _compression.compress(
        inputPath: rawPath,
        outputPath: outputPath,
        durationMs: durationMs,
      )) {
        state = state.copyWith(compressionProgress: progress);
      }
      await _repo.deleteFile(rawPath);
      state = state.copyWith(
        flowState: RecordingFlowState.uploading,
        videoPath: outputPath,
        compressionProgress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        flowState: RecordingFlowState.error,
        errorMessage: 'Compression failed: $e',
      );
    }
  }

  // ── Upload completion (called by UploadNotifier) ──────────────────────────

  void markDone() {
    state = state.copyWith(flowState: RecordingFlowState.done);
  }

  void markError(String message) {
    state = state.copyWith(
      flowState: RecordingFlowState.error,
      errorMessage: message,
    );
  }

  void markInsertingJob() {
    state = state.copyWith(flowState: RecordingFlowState.insertingJob);
  }

  // ── Error reset ────────────────────────────────────────────────────────────

  Future<void> retryFromIdle() async {
    state = RecordingState(matchId: state.matchId);
    await initialize();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _courtCheckTimer?.cancel();
    _repo.stopImageStream().then((_) => _repo.dispose());
    super.dispose();
  }
}

/// Provider parameterized by matchId.
final recordingNotifierProvider = StateNotifierProvider.autoDispose
    .family<RecordingNotifier, RecordingState, String>(
  (ref, matchId) => RecordingNotifier(matchId: matchId),
);
