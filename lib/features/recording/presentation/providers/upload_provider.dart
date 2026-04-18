import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/recording/data/repositories/processing_job_repository.dart';
import 'package:padel_app/features/recording/data/repositories/upload_repository.dart';
import 'package:padel_app/features/recording/presentation/providers/recording_provider.dart';

enum UploadFlowState { idle, fetchingUrl, uploading, insertingJob, done, error }

class UploadState {
  final UploadFlowState flowState;
  final int bytesUploaded;
  final int totalBytes;
  final String? errorMessage;

  const UploadState({
    this.flowState = UploadFlowState.idle,
    this.bytesUploaded = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  double get progressPct => totalBytes > 0 ? bytesUploaded / totalBytes : 0.0;

  UploadState copyWith({
    UploadFlowState? flowState,
    int? bytesUploaded,
    int? totalBytes,
    String? errorMessage,
  }) {
    return UploadState(
      flowState: flowState ?? this.flowState,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Handles the upload and job insertion steps.
///
/// The RecordingScreen watches both recordingNotifierProvider and
/// uploadNotifierProvider. When recording transitions to `uploading`,
/// the screen calls uploadNotifier.startUpload().
class UploadNotifier extends StateNotifier<UploadState> {
  final UploadRepository _uploadRepo;
  final ProcessingJobRepository _jobRepo;
  final Ref _ref;

  UploadNotifier(this._ref)
      : _uploadRepo = UploadRepository(),
        _jobRepo = ProcessingJobRepository(),
        super(const UploadState());

  Future<void> startUpload({
    required String matchId,
    required String videoPath,
  }) async {
    final file = File(videoPath);
    final fileSizeBytes = await file.length();

    state = state.copyWith(
      flowState: UploadFlowState.fetchingUrl,
      totalBytes: fileSizeBytes,
      bytesUploaded: 0,
    );

    UploadUrlResponse urlResponse;
    try {
      urlResponse = await _uploadRepo.getUploadUrl(
        matchId: matchId,
        fileSizeBytes: fileSizeBytes,
      );
    } catch (e) {
      state = state.copyWith(
        flowState: UploadFlowState.error,
        errorMessage: 'Could not get upload URL: $e',
      );
      _ref
          .read(recordingNotifierProvider(matchId).notifier)
          .markError('Could not get upload URL');
      return;
    }

    state = state.copyWith(flowState: UploadFlowState.uploading);

    try {
      await for (final progress in _uploadRepo.uploadToR2(
        uploadUrl: urlResponse.uploadUrl,
        filePath: videoPath,
      )) {
        state = state.copyWith(
          bytesUploaded: progress.bytesUploaded,
          totalBytes: progress.totalBytes,
        );
      }
    } catch (e) {
      state = state.copyWith(
        flowState: UploadFlowState.error,
        errorMessage: 'Upload failed: $e',
      );
      _ref
          .read(recordingNotifierProvider(matchId).notifier)
          .markError('Upload failed after retries');
      return;
    }

    // Build the full R2 public URL from the object key.
    // The backend uses this to download the video for processing.
    final r2AccountId =
        const String.fromEnvironment('CLOUDFLARE_R2_ACCOUNT_ID');
    final r2Bucket = const String.fromEnvironment(
      'CLOUDFLARE_R2_BUCKET',
      defaultValue: 'padel-match-videos',
    );
    final videoUrl = r2AccountId.isNotEmpty
        ? 'https://$r2AccountId.r2.cloudflarestorage.com/$r2Bucket/${urlResponse.objectKey}'
        : urlResponse.objectKey;

    state = state.copyWith(flowState: UploadFlowState.insertingJob);
    _ref
        .read(recordingNotifierProvider(matchId).notifier)
        .markInsertingJob();

    try {
      await _jobRepo.insertJob(matchId: matchId, videoUrl: videoUrl);
    } catch (e) {
      state = state.copyWith(
        flowState: UploadFlowState.error,
        errorMessage: 'Failed to queue analysis: $e',
      );
      _ref
          .read(recordingNotifierProvider(matchId).notifier)
          .markError('Failed to queue analysis job');
      return;
    }

    // Delete compressed file — no longer needed.
    try {
      await File(videoPath).delete();
    } catch (_) {}

    state = state.copyWith(flowState: UploadFlowState.done);
    _ref.read(recordingNotifierProvider(matchId).notifier).markDone();
  }
}

final uploadNotifierProvider =
    StateNotifierProvider.autoDispose<UploadNotifier, UploadState>(
  (ref) => UploadNotifier(ref),
);

/// Handles upload + job insertion for gallery-picked videos.
///
/// Same flow as [UploadNotifier] but decoupled from the recording screen —
/// no dependency on [recordingNotifierProvider], and does not delete the
/// source file (it lives in the user's gallery).
class GalleryUploadNotifier extends StateNotifier<UploadState> {
  final UploadRepository _uploadRepo;
  final ProcessingJobRepository _jobRepo;

  GalleryUploadNotifier()
      : _uploadRepo = UploadRepository(),
        _jobRepo = ProcessingJobRepository(),
        super(const UploadState());

  Future<void> startUpload({
    required String matchId,
    required String videoPath,
  }) async {
    final file = File(videoPath);
    final fileSizeBytes = await file.length();

    state = state.copyWith(
      flowState: UploadFlowState.fetchingUrl,
      totalBytes: fileSizeBytes,
      bytesUploaded: 0,
    );

    UploadUrlResponse urlResponse;
    try {
      urlResponse = await _uploadRepo.getUploadUrl(
        matchId: matchId,
        fileSizeBytes: fileSizeBytes,
      );
    } catch (e) {
      state = state.copyWith(
        flowState: UploadFlowState.error,
        errorMessage: 'Could not get upload URL: $e',
      );
      return;
    }

    state = state.copyWith(flowState: UploadFlowState.uploading);

    try {
      await for (final progress in _uploadRepo.uploadToR2(
        uploadUrl: urlResponse.uploadUrl,
        filePath: videoPath,
      )) {
        state = state.copyWith(
          bytesUploaded: progress.bytesUploaded,
          totalBytes: progress.totalBytes,
        );
      }
    } catch (e) {
      state = state.copyWith(
        flowState: UploadFlowState.error,
        errorMessage: 'Upload failed: $e',
      );
      return;
    }

    final r2AccountId =
        const String.fromEnvironment('CLOUDFLARE_R2_ACCOUNT_ID');
    final r2Bucket = const String.fromEnvironment(
      'CLOUDFLARE_R2_BUCKET',
      defaultValue: 'padel-match-videos',
    );
    final videoUrl = r2AccountId.isNotEmpty
        ? 'https://$r2AccountId.r2.cloudflarestorage.com/$r2Bucket/${urlResponse.objectKey}'
        : urlResponse.objectKey;

    state = state.copyWith(flowState: UploadFlowState.insertingJob);

    try {
      await _jobRepo.insertJob(matchId: matchId, videoUrl: videoUrl);
    } catch (e) {
      state = state.copyWith(
        flowState: UploadFlowState.error,
        errorMessage: 'Failed to queue analysis: $e',
      );
      return;
    }

    // Do NOT delete the source file — it belongs to the user's gallery.

    state = state.copyWith(flowState: UploadFlowState.done);
  }
}

final galleryUploadNotifierProvider =
    StateNotifierProvider<GalleryUploadNotifier, UploadState>(
  (ref) => GalleryUploadNotifier(),
);
