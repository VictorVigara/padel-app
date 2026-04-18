import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/match/data/repositories/match_repository.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/domain/models/match_filter.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository();
});

final matchListProvider =
    FutureProvider.autoDispose<List<PadelMatch>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(matchRepositoryProvider);
  return repo.getMatches(user.id);
});

final matchDetailProvider =
    FutureProvider.autoDispose.family<PadelMatch?, String>((ref, matchId) async {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.getMatch(matchId);
});

final matchStatsProvider =
    FutureProvider.autoDispose.family<List<MatchStats>, String>((ref, matchId) async {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.getMatchStats(matchId);
});

// ── Analysis status badges ────────────────────────────────────────────────────

enum AnalysisStatus { queued, processing, done, failed }

class AnalysisBadgeInfo {
  final AnalysisStatus status;
  final String? jobId;

  const AnalysisBadgeInfo({required this.status, this.jobId});
}

/// Returns the latest processing_job for a match, or null if none exists.
///
/// Auto-invalidates every 30 seconds while the job is queued/processing so
/// the badge in match history updates without requiring a manual refresh.
final analysisStatusProvider = FutureProvider.autoDispose
    .family<AnalysisBadgeInfo?, String>((ref, matchId) async {
  if (!SupabaseConfig.isConfigured) return null;

  final response = await SupabaseConfig.client
      .from('processing_jobs')
      .select('id, status')
      .eq('match_id', matchId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) return null;

  final status = switch (response['status'] as String) {
    'queued' => AnalysisStatus.queued,
    'processing' => AnalysisStatus.processing,
    'done' => AnalysisStatus.done,
    'failed' => AnalysisStatus.failed,
    _ => AnalysisStatus.queued,
  };

  // Auto-refresh while job is in-flight.
  if (status == AnalysisStatus.queued || status == AnalysisStatus.processing) {
    Future.delayed(const Duration(seconds: 30), () {
      ref.invalidateSelf();
    });
  }

  return AnalysisBadgeInfo(
    status: status,
    jobId: response['id'] as String,
  );
});

/// Creates a minimal draft match (status=recording) for the current user and
/// returns the new match ID. Used by the camera button and gallery upload flow.
final createDraftMatchProvider = Provider<Future<String> Function({MatchStatus status})>((ref) {
  return ({MatchStatus status = MatchStatus.recording}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Not logged in');
    final repo = ref.read(matchRepositoryProvider);
    final match = await repo.createMatch(
      PadelMatch(
        createdBy: user.id,
        matchDate: DateTime.now(),
        status: status,
      ),
    );
    ref.invalidate(matchListProvider);
    return match.id!;
  };
});

/// Current filter state for match history.
final matchFilterProvider = StateProvider<MatchFilter>((ref) => const MatchFilter());

/// Matches filtered by the current filter state (client-side).
final filteredMatchListProvider =
    FutureProvider.autoDispose<List<PadelMatch>>((ref) async {
  final matches = await ref.watch(matchListProvider.future);
  final filter = ref.watch(matchFilterProvider);

  if (!filter.isActive) return matches;

  return matches.where((m) {
    if (filter.result == 'won' && m.winnerTeam != 1) return false;
    if (filter.result == 'lost' && m.winnerTeam != 2) return false;
    if (filter.matchType != null && m.matchType != filter.matchType) return false;
    if (filter.courtSurface != null && m.courtSurface != filter.courtSurface) {
      return false;
    }
    if (filter.dateFrom != null && m.matchDate.isBefore(filter.dateFrom!)) {
      return false;
    }
    if (filter.dateTo != null &&
        m.matchDate.isAfter(filter.dateTo!.add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }).toList();
});
