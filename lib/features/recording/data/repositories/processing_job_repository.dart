import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:padel_app/features/recording/domain/models/processing_job.dart';

/// Queues a video for analysis via POST /analyze on the backend.
class ProcessingJobRepository {
  final String _backendUrl;

  ProcessingJobRepository({String? backendUrl})
      : _backendUrl = backendUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  /// Call POST /analyze to queue the job.
  /// The backend inserts the row and spawns the GPU worker if calibration is ready.
  Future<ProcessingJob> insertJob({
    required String matchId,
    required String videoUrl,
  }) async {
    final uri = Uri.parse('$_backendUrl/analyze');
    print('[DEBUG] ProcessingJobRepository.insertJob: POST $uri');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'match_id': matchId,
        'video_url': videoUrl,
      }),
    );

    print('[DEBUG] POST /analyze: status=${response.statusCode} body=${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to queue analysis: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final jobId = json['job_id'] as String? ?? matchId;

    return ProcessingJob(
      jobId: jobId,
      matchId: matchId,
      videoUrl: videoUrl,
    );
  }
}
