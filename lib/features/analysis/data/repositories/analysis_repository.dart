import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/analysis/domain/models/analysis_result.dart';

class AnalysisRepository {
  /// Get analysis result for a match, if available.
  ///
  /// Returns null if no analysis exists for this match yet.
  /// The presence of a row in match_analyses with status='done' indicates analysis is complete.
  Future<AnalysisResult?> getAnalysis(String matchId) async {
    final response = await SupabaseConfig.client
        .from('match_analyses')
        .select('result')
        .eq('match_id', matchId)
        .eq('status', 'done')
        .maybeSingle();

    if (response == null) return null;

    final resultJson = response['result'];
    if (resultJson == null) return null;

    return AnalysisResult.fromJson(resultJson as Map<String, dynamic>);
  }
}
