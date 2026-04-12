import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/recording/domain/models/processing_job.dart';

/// Inserts a processing_jobs row so the backend poller can pick it up.
class ProcessingJobRepository {
  ProcessingJobRepository();

  /// Insert a new row in processing_jobs.
  /// The backend poller picks it up within 30s automatically.
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

    return ProcessingJob(
      jobId: jobId,
      matchId: matchId,
      videoUrl: videoUrl,
    );
  }
}
