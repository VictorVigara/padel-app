import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:http/http.dart' as http;

/// Response from POST /upload-url.
class UploadUrlResponse {
  final String uploadUrl;
  final String objectKey;
  final String expiresAt;

  const UploadUrlResponse({
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresAt,
  });

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    return UploadUrlResponse(
      uploadUrl: json['upload_url'] as String,
      objectKey: json['object_key'] as String,
      expiresAt: json['expires_at'] as String,
    );
  }
}

/// Upload progress snapshot.
class UploadProgress {
  final int bytesUploaded;
  final int totalBytes;

  const UploadProgress({required this.bytesUploaded, required this.totalBytes});

  double get pct => totalBytes > 0 ? bytesUploaded / totalBytes : 0.0;
}

/// Handles fetching a pre-signed R2 URL and uploading the compressed video.
///
/// Uses background_downloader for the upload so that NSURLSession (iOS) and
/// WorkManager (Android) keep the transfer alive when the screen locks.
class UploadRepository {
  final String _backendUrl;

  UploadRepository({String? backendUrl})
      : _backendUrl = backendUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  /// Fetch a pre-signed PUT URL from the backend for the given match.
  Future<UploadUrlResponse> getUploadUrl({
    required String matchId,
    required int fileSizeBytes,
  }) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/upload-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'match_id': matchId,
        'content_length': fileSizeBytes,
        'content_type': 'video/mp4',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get upload URL: ${response.body}');
    }

    return UploadUrlResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Upload the file at [filePath] to R2 using [uploadUrl].
  ///
  /// Yields [UploadProgress] events as the upload proceeds.
  /// Uses background_downloader's UploadTask so the transfer survives
  /// screen lock on both iOS (NSURLSession) and Android (WorkManager).
  Stream<UploadProgress> uploadToR2({
    required String uploadUrl,
    required String filePath,
  }) async* {
    final file = File(filePath);
    final totalBytes = await file.length();

    final task = UploadTask(
      url: uploadUrl,
      filename: filePath.split('/').last,
      directory: filePath.substring(0, filePath.lastIndexOf('/')),
      httpRequestMethod: 'PUT',
      headers: {'Content-Type': 'video/mp4'},
      retries: 3,
      updates: Updates.progressAndStatus,
    );

    final completer = <UploadProgress>[];
    bool done = false;
    Object? uploadError;

    FileDownloader().updates.listen((update) {
      if (update is TaskProgressUpdate && update.task.taskId == task.taskId) {
        if (update.progress >= 0) {
          completer.add(UploadProgress(
            bytesUploaded: (update.progress * totalBytes).round(),
            totalBytes: totalBytes,
          ));
        }
      } else if (update is TaskStatusUpdate &&
          update.task.taskId == task.taskId) {
        if (update.status == TaskStatus.complete) {
          done = true;
        } else if (update.status == TaskStatus.failed ||
            update.status == TaskStatus.notFound) {
          uploadError = Exception('Upload failed: ${update.status}');
          done = true;
        }
      }
    });

    await FileDownloader().enqueue(task);

    // Poll until done, yielding progress updates.
    while (!done) {
      await Future.delayed(const Duration(milliseconds: 250));
      for (final p in completer) {
        yield p;
      }
      completer.clear();
    }

    // Yield any remaining progress.
    for (final p in completer) {
      yield p;
    }

    if (uploadError != null) throw uploadError!;

    yield UploadProgress(bytesUploaded: totalBytes, totalBytes: totalBytes);
  }
}
