import 'package:flutter_riverpod/flutter_riverpod.dart';
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
