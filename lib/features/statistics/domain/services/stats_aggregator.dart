import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/match/domain/models/match_stats.dart';
import 'package:padel_app/features/statistics/domain/models/aggregated_stats.dart';

class StatsAggregator {
  static OverviewStats computeOverview(List<PadelMatch> matches) {
    final total = matches.length;
    final wins = matches.where((m) => m.winnerTeam == 1).length;
    final losses = total - wins;
    final winRate = total > 0 ? wins / total : 0.0;
    return OverviewStats(
      totalMatches: total,
      wins: wins,
      losses: losses,
      winRate: winRate,
    );
  }

  static ServeAggregation computeServes(List<MatchStats> stats) {
    if (stats.isEmpty) {
      return const ServeAggregation(
        avgFirstServePercent: 0,
        avgAcesPerMatch: 0,
        avgDoubleFaultsPerMatch: 0,
        firstServePercentByMatch: [],
      );
    }

    final withServes = stats.where((s) => s.firstServeTotal > 0).toList();
    final percentages =
        withServes.map((s) => s.firstServePercentage).toList();
    final avgPercent =
        percentages.isEmpty ? 0.0 : percentages.reduce((a, b) => a + b) / percentages.length;

    final totalAces = stats.fold<int>(0, (sum, s) => sum + s.aces);
    final totalDFs = stats.fold<int>(0, (sum, s) => sum + s.doubleFaults);

    return ServeAggregation(
      avgFirstServePercent: avgPercent,
      avgAcesPerMatch: totalAces / stats.length,
      avgDoubleFaultsPerMatch: totalDFs / stats.length,
      firstServePercentByMatch: percentages,
    );
  }

  static ShotDistribution computeShots(List<MatchStats> stats) {
    var winners = 0, ue = 0, fe = 0;
    var bandeja = 0, vibora = 0, smash = 0, lob = 0, volley = 0;

    for (final s in stats) {
      winners += s.winners;
      ue += s.unforcedErrors;
      fe += s.forcedErrors;
      bandeja += s.bandejaWinners;
      vibora += s.viboraWinners;
      smash += s.smashWinners;
      lob += s.lobWinners;
      volley += s.volleyWinners;
    }

    return ShotDistribution(
      totalWinners: winners,
      totalUnforcedErrors: ue,
      totalForcedErrors: fe,
      bandejaWinners: bandeja,
      viboraWinners: vibora,
      smashWinners: smash,
      lobWinners: lob,
      volleyWinners: volley,
    );
  }

  static List<SurfaceBreakdown> computeBySurface(List<PadelMatch> matches) {
    final grouped = <String, List<PadelMatch>>{};
    for (final m in matches) {
      final surface = m.courtSurface ?? 'other';
      grouped.putIfAbsent(surface, () => []).add(m);
    }

    return grouped.entries.map((e) {
      final wins = e.value.where((m) => m.winnerTeam == 1).length;
      return SurfaceBreakdown(
        surface: e.key,
        matches: e.value.length,
        wins: wins,
        winRate: e.value.isNotEmpty ? wins / e.value.length : 0.0,
      );
    }).toList()
      ..sort((a, b) => b.matches.compareTo(a.matches));
  }

  static List<MatchTypeBreakdown> computeByMatchType(List<PadelMatch> matches) {
    final grouped = <String, List<PadelMatch>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.matchType ?? 'unknown', () => []).add(m);
    }

    return grouped.entries.map((e) {
      final wins = e.value.where((m) => m.winnerTeam == 1).length;
      return MatchTypeBreakdown(
        matchType: e.key,
        matches: e.value.length,
        wins: wins,
        winRate: e.value.isNotEmpty ? wins / e.value.length : 0.0,
      );
    }).toList()
      ..sort((a, b) => b.matches.compareTo(a.matches));
  }
}
