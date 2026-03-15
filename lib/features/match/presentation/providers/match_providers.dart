import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/features/match/data/repositories/match_repository.dart';
import 'package:padel_app/features/match/domain/models/match.dart';
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
