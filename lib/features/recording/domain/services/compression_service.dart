import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Compresses a recorded video to ~5 Mbps 1080p using ffmpeg_kit_flutter.
///
/// Streams progress as a double from 0.0 to 1.0.
/// Throws [CompressionException] on failure.
class CompressionService {
  /// Extracts a single JPEG frame from [inputPath] at the 1-second mark.
  ///
  /// Saves to [outputPath] (should end in .jpg).
  /// Throws [FrameExtractionException] on failure.
  Future<void> extractFrame({
    required String inputPath,
    required String outputPath,
  }) async {
    final session = await FFmpegKit.execute(
      '-ss 1 -i "$inputPath" -vframes 1 -q:v 2 -y "$outputPath"',
    );
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw FrameExtractionException('FFmpeg failed: $logs');
    }
  }

  /// Compress [inputPath] to [outputPath].
  ///
  /// [durationMs] is the total video duration in milliseconds, used to
  /// compute progress percentage from ffmpeg statistics.
  Stream<double> compress({
    required String inputPath,
    required String outputPath,
    required int durationMs,
  }) async* {
    final controller = StreamController<double>();

    // Enable statistics callback to get time-based progress.
    FFmpegKitConfig.enableStatisticsCallback((stats) {
      if (durationMs > 0) {
        final timeMs = stats.getTime(); // ms processed so far
        final progress = (timeMs / durationMs).clamp(0.0, 1.0);
        if (!controller.isClosed) controller.add(progress);
      }
    });

    // -c:v libx264   H.264, widely compatible
    // -b:v 5000k     target 5 Mbps video bitrate
    // -maxrate 5000k cap peak bitrate
    // -bufsize 10000k VBV buffer = 2x maxrate
    // -vf scale=1920:1080  force 1080p output
    // -r 30          lock to 30 fps
    // -c:a aac -b:a 128k  audio codec
    // -y             overwrite output without prompting
    FFmpegKit.executeAsync(
      '-i "$inputPath" -c:v libx264 -b:v 5000k -maxrate 5000k -bufsize 10000k'
      ' -vf "scale=1920:1080" -r 30 -c:a aac -b:a 128k -y "$outputPath"',
      (session) async {
        FFmpegKitConfig.enableStatisticsCallback(null);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          if (!controller.isClosed) {
            controller.add(1.0);
            controller.close();
          }
        } else {
          final logs = await session.getAllLogsAsString();
          if (!controller.isClosed) {
            controller.addError(
              CompressionException('FFmpeg failed: $logs'),
            );
            controller.close();
          }
        }
      },
    );

    yield* controller.stream;
  }
}

class CompressionException implements Exception {
  final String message;
  const CompressionException(this.message);
  @override
  String toString() => 'CompressionException: $message';
}

class FrameExtractionException implements Exception {
  final String message;
  const FrameExtractionException(this.message);
  @override
  String toString() => 'FrameExtractionException: $message';
}
