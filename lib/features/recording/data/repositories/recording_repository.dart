import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart' show Offset;

/// Owns the CameraController lifecycle and video recording.
///
/// The notifier calls methods on this repository; it never holds the
/// CameraController directly. This keeps the notifier testable.
class RecordingRepository {
  CameraController? _controller;
  Timer? _exposureLockTimer;

  CameraController? get controller => _controller;

  /// Initialize the back camera at 1080p.
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      back,
      ResolutionPreset.high, // 1080p
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    // Lock focus to infinity immediately — court is always far away.
    await _controller!.setFocusMode(FocusMode.locked);
    await _controller!.setFocusPoint(const Offset(0.5, 0.5));
  }

  /// Start video recording.
  ///
  /// Locks exposure after 3 seconds to prevent drift when players move
  /// into shadow (per CLAUDE.md iPhone recording requirements).
  Future<void> startRecording() async {
    final ctrl = _requireController();
    await ctrl.startVideoRecording();

    _exposureLockTimer = Timer(const Duration(seconds: 3), () async {
      try {
        await ctrl.setExposureMode(ExposureMode.locked);
        await ctrl.setExposurePoint(const Offset(0.5, 0.5));
      } catch (_) {
        // Exposure lock is best-effort — some devices don't support it.
      }
    });
  }

  /// Stop recording and return the path to the raw video file.
  Future<String> stopRecording() async {
    _exposureLockTimer?.cancel();
    _exposureLockTimer = null;
    final file = await _requireController().stopVideoRecording();
    return file.path;
  }

  /// Start streaming frames for court detection (called before recording).
  void startImageStream(void Function(CameraImage) onImage) {
    _requireController().startImageStream(onImage);
  }

  /// Stop streaming frames.
  Future<void> stopImageStream() async {
    if (_controller?.value.isStreamingImages == true) {
      await _controller!.stopImageStream();
    }
  }

  /// Delete a file from the local filesystem.
  Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort — don't crash if file is already gone.
    }
  }

  Future<void> dispose() async {
    _exposureLockTimer?.cancel();
    _exposureLockTimer = null;
    await _controller?.dispose();
    _controller = null;
  }

  CameraController _requireController() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      throw StateError('CameraController is not initialized');
    }
    return ctrl;
  }
}
