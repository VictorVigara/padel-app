import 'package:flutter/material.dart';
import 'package:padel_app/features/recording/domain/models/recording_state.dart';

/// Bottom control bar: elapsed timer + start/stop button.
///
/// The record button is disabled for the first 5 seconds of recording to
/// prevent accidental taps stopping a just-started session.
class RecordingControlsWidget extends StatelessWidget {
  final RecordingState state;
  final VoidCallback? onStartStop;

  const RecordingControlsWidget({
    super.key,
    required this.state,
    this.onStartStop,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = state.flowState == RecordingFlowState.recording;
    // Allow starting even if court detection hasn't passed — Sprint 2 will enforce this.
    final canStart = state.flowState == RecordingFlowState.readyToRecord ||
        state.flowState == RecordingFlowState.badAngle ||
        state.flowState == RecordingFlowState.detectingCourt;
    final minRecordingElapsed = state.elapsedSeconds >= 5;

    final buttonEnabled = canStart || (isRecording && minRecordingElapsed);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withAlpha(180), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRecording)
                Text(
                  _formatElapsed(state.elapsedSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: buttonEnabled ? onStartStop : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: buttonEnabled
                        ? (isRecording ? Colors.red : Colors.white)
                        : Colors.white38,
                    border: Border.all(
                      color: Colors.white,
                      width: isRecording ? 3 : 4,
                    ),
                  ),
                  child: isRecording
                      ? const Icon(Icons.stop, color: Colors.white, size: 32)
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _buttonLabel(state.flowState, minRecordingElapsed),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _buttonLabel(RecordingFlowState flowState, bool minElapsed) {
    return switch (flowState) {
      RecordingFlowState.detectingCourt => 'Checking angle…',
      RecordingFlowState.badAngle => 'Adjust camera to start',
      RecordingFlowState.readyToRecord => 'Tap to record',
      RecordingFlowState.recording =>
        minElapsed ? 'Tap to stop' : 'Recording…',
      RecordingFlowState.stopping => 'Stopping…',
      RecordingFlowState.compressing => 'Compressing…',
      RecordingFlowState.uploading => 'Uploading…',
      RecordingFlowState.insertingJob => 'Queuing analysis…',
      RecordingFlowState.done => 'Done!',
      RecordingFlowState.error => 'Error',
      _ => '',
    };
  }
}
