/// Represents a row in the processing_jobs Supabase table.
class ProcessingJob {
  final String jobId;
  final String matchId;
  final String videoUrl;

  const ProcessingJob({
    required this.jobId,
    required this.matchId,
    required this.videoUrl,
  });
}
