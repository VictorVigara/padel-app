import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';

class MatchRepository {
  /// Create a new match and optionally save stats for the current user.
  Future<PadelMatch> createMatch(PadelMatch match, {MatchStats? stats}) async {
    final response = await SupabaseConfig.client
        .from('matches')
        .insert(match.toJson())
        .select()
        .single();

    final created = PadelMatch.fromJson(response);

    if (stats != null && created.id != null) {
      await SupabaseConfig.client.from('match_stats').insert(
            stats.copyWith(matchId: created.id!).toJson(),
          );
    }

    return created;
  }

  /// Get all matches for the current user, newest first.
  Future<List<PadelMatch>> getMatches(String userId) async {
    final response = await SupabaseConfig.client
        .from('matches')
        .select()
        .order('match_date', ascending: false);

    return (response as List)
        .map((json) => PadelMatch.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single match by ID.
  Future<PadelMatch?> getMatch(String matchId) async {
    final response = await SupabaseConfig.client
        .from('matches')
        .select()
        .eq('id', matchId)
        .maybeSingle();
    if (response == null) return null;
    return PadelMatch.fromJson(response);
  }

  /// Update an existing match and optionally upsert stats.
  Future<PadelMatch> updateMatch(PadelMatch match, {MatchStats? stats}) async {
    final response = await SupabaseConfig.client
        .from('matches')
        .update({
          ...match.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', match.id!)
        .select()
        .single();

    final updated = PadelMatch.fromJson(response);

    if (stats != null && updated.id != null) {
      await SupabaseConfig.client.from('match_stats').upsert(
            stats.copyWith(matchId: updated.id!).toJson(),
          );
    }

    return updated;
  }

  /// Delete a match.
  Future<void> deleteMatch(String matchId) async {
    await SupabaseConfig.client.from('matches').delete().eq('id', matchId);
  }

  /// Get stats for a match.
  Future<List<MatchStats>> getMatchStats(String matchId) async {
    final response = await SupabaseConfig.client
        .from('match_stats')
        .select()
        .eq('match_id', matchId);
    return (response as List)
        .map((json) => MatchStats.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
