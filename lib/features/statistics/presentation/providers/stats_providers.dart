import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';
import 'package:padel_app/features/match/presentation/providers/match_providers.dart';
import 'package:padel_app/features/statistics/domain/models/aggregated_stats.dart';
import 'package:padel_app/features/statistics/domain/services/stats_aggregator.dart';

/// All match stats for the current user.
final allUserStatsProvider =
    FutureProvider.autoDispose<List<MatchStats>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final response = await SupabaseConfig.client
      .from('match_stats')
      .select()
      .eq('player_id', user.id);
  return (response as List)
      .map((json) => MatchStats.fromJson(json as Map<String, dynamic>))
      .toList();
});

final overviewStatsProvider =
    FutureProvider.autoDispose<OverviewStats>((ref) async {
  final matches = await ref.watch(matchListProvider.future);
  return StatsAggregator.computeOverview(matches);
});

final serveStatsProvider =
    FutureProvider.autoDispose<ServeAggregation>((ref) async {
  final stats = await ref.watch(allUserStatsProvider.future);
  return StatsAggregator.computeServes(stats);
});

final shotDistributionProvider =
    FutureProvider.autoDispose<ShotDistribution>((ref) async {
  final stats = await ref.watch(allUserStatsProvider.future);
  return StatsAggregator.computeShots(stats);
});

final surfaceBreakdownProvider =
    FutureProvider.autoDispose<List<SurfaceBreakdown>>((ref) async {
  final matches = await ref.watch(matchListProvider.future);
  return StatsAggregator.computeBySurface(matches);
});

final matchTypeBreakdownProvider =
    FutureProvider.autoDispose<List<MatchTypeBreakdown>>((ref) async {
  final matches = await ref.watch(matchListProvider.future);
  return StatsAggregator.computeByMatchType(matches);
});
