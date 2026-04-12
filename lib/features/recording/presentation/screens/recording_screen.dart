import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/features/recording/domain/models/recording_state.dart';
import 'package:padel_app/features/recording/presentation/providers/recording_provider.dart';
import 'package:padel_app/features/recording/presentation/providers/upload_provider.dart';
import 'package:padel_app/features/recording/presentation/widgets/camera_preview_widget.dart';
import 'package:padel_app/features/recording/presentation/widgets/compression_progress_widget.dart';
import 'package:padel_app/features/recording/presentation/widgets/court_guide_overlay.dart';
import 'package:padel_app/features/recording/presentation/widgets/recording_controls_widget.dart';
import 'package:padel_app/features/recording/presentation/widgets/upload_progress_widget.dart';

/// Fullscreen recording screen.
///
/// Flow:
///   1. Camera initialises, court detection runs on live frames.
///   2. When angle is good, user taps start.
///   3. After stop, compression + upload happen with progress UI.
///   4. On done, navigates back to /matches/{matchId}.
class RecordingScreen extends ConsumerStatefulWidget {
  final String matchId;

  const RecordingScreen({super.key, required this.matchId});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _uploadStarted = false;

  @override
  void initState() {
    super.initState();
    // Lock to landscape for recording — court fills the frame better.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recordingNotifierProvider(widget.matchId).notifier)
          .initialize();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingNotifierProvider(widget.matchId));
    final uploadState = ref.watch(uploadNotifierProvider);

    // When recording transitions to "uploading", kick off the upload once.
    ref.listen(recordingNotifierProvider(widget.matchId), (prev, next) {
      if (!_uploadStarted &&
          next.flowState == RecordingFlowState.uploading &&
          next.videoPath != null) {
        _uploadStarted = true;
        ref.read(uploadNotifierProvider.notifier).startUpload(
              matchId: widget.matchId,
              videoPath: next.videoPath!,
            );
      }

      // Navigate back when done.
      if (next.flowState == RecordingFlowState.done) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/matches/${widget.matchId}');
        });
      }
    });

    final notifier =
        ref.read(recordingNotifierProvider(widget.matchId).notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreviewWidget(controller: notifier.cameraController),

          // Court angle guide (shown while not recording)
          if (recordingState.flowState == RecordingFlowState.detectingCourt ||
              recordingState.flowState == RecordingFlowState.readyToRecord ||
              recordingState.flowState == RecordingFlowState.badAngle)
            CourtGuideOverlay(
              courtOk: recordingState.courtOk,
              message: recordingState.courtResultMessage,
            ),

          // Compression progress
          if (recordingState.flowState == RecordingFlowState.compressing)
            CompressionProgressWidget(
              progress: recordingState.compressionProgress,
            ),

          // Upload progress
          if (recordingState.flowState == RecordingFlowState.uploading ||
              recordingState.flowState == RecordingFlowState.insertingJob)
            UploadProgressWidget(
              bytesUploaded: uploadState.bytesUploaded,
              totalBytes: uploadState.totalBytes,
            ),

          // Recording controls (hidden during compression/upload/done)
          if (recordingState.flowState != RecordingFlowState.compressing &&
              recordingState.flowState != RecordingFlowState.uploading &&
              recordingState.flowState != RecordingFlowState.insertingJob &&
              recordingState.flowState != RecordingFlowState.done)
            RecordingControlsWidget(
              state: recordingState,
              onStartStop: () {
                final flow = recordingState.flowState;
                if (flow == RecordingFlowState.readyToRecord) {
                  notifier.startRecording();
                } else if (flow == RecordingFlowState.recording) {
                  notifier.stopRecording();
                }
              },
            ),

          // Error state
          if (recordingState.flowState == RecordingFlowState.error)
            _ErrorOverlay(
              message: recordingState.errorMessage ?? 'Something went wrong',
              onRetry: () {
                _uploadStarted = false;
                notifier.retryFromIdle();
              },
              onClose: () => context.pop(),
            ),

          // Back button (top-left, visible when not recording)
          if (recordingState.flowState != RecordingFlowState.recording &&
              recordingState.flowState != RecordingFlowState.compressing &&
              recordingState.flowState != RecordingFlowState.uploading &&
              recordingState.flowState != RecordingFlowState.insertingJob)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onClose,
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
