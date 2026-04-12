import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/recording/domain/models/processing_job.dart';

/// Inserts a processing_jobs row and triggers the backend analysis job.
class ProcessingJobRepository {
  final String _backendUrl;

  ProcessingJobRepository({String? backendUrl})
      : _backendUrl = backendUrl ??
            const String.fromEnvironment(
              'BACKEND_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  /// Insert a new row in processing_jobs and call POST /analyze on the backend.
  ///
  /// [videoUrl] is the full R2 HTTPS URL:
  ///   https://{account}.r2.cloudflarestorage.com/{bucket}/{objectKey}
  Future<ProcessingJob> insertJob({
    required String matchId,
    required String videoUrl,
  }) async {
    // Insert row in Supabase — this makes the job visible in the match history
    // badge immediately, even before the backend picks it up.
    final result = await SupabaseConfig.client
        .from('processing_jobs')
        .insert({
          'match_id': matchId,
          'video_url': videoUrl,
          'status': 'queued',
        })
        .select('id')
        .single();

    final jobId = result['id'] as String;

    // Notify the backend to wake up and process this job.
    // The backend will pick it up via the poller anyway, but this triggers
    // it immediately instead of waiting up to 30 seconds.
    try {
      await http.post(
        Uri.parse('$_backendUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'match_id': matchId, 'video_url': videoUrl}),
      );
    } catch (_) {
      // Best-effort — the poller will pick up the job within 30s regardless.
    }

    return ProcessingJob(
      jobId: jobId,
      matchId: matchId,
      videoUrl: videoUrl,
    );
  }
}
