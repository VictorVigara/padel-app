class OverviewStats {
  final int totalMatches;
  final int wins;
  final int losses;
  final double winRate;

  const OverviewStats({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.winRate,
  });
}

class ServeAggregation {
  final double avgFirstServePercent;
  final double avgAcesPerMatch;
  final double avgDoubleFaultsPerMatch;
  final List<double> firstServePercentByMatch;

  const ServeAggregation({
    required this.avgFirstServePercent,
    required this.avgAcesPerMatch,
    required this.avgDoubleFaultsPerMatch,
    required this.firstServePercentByMatch,
  });
}

class ShotDistribution {
  final int totalWinners;
  final int totalUnforcedErrors;
  final int totalForcedErrors;
  final int bandejaWinners;
  final int viboraWinners;
  final int smashWinners;
  final int lobWinners;
  final int volleyWinners;

  const ShotDistribution({
    required this.totalWinners,
    required this.totalUnforcedErrors,
    required this.totalForcedErrors,
    required this.bandejaWinners,
    required this.viboraWinners,
    required this.smashWinners,
    required this.lobWinners,
    required this.volleyWinners,
  });

  int get totalPadelShots =>
      bandejaWinners + viboraWinners + smashWinners + lobWinners + volleyWinners;
}

class SurfaceBreakdown {
  final String surface;
  final int matches;
  final int wins;
  final double winRate;

  const SurfaceBreakdown({
    required this.surface,
    required this.matches,
    required this.wins,
    required this.winRate,
  });
}

class MatchTypeBreakdown {
  final String matchType;
  final int matches;
  final int wins;
  final double winRate;

  const MatchTypeBreakdown({
    required this.matchType,
    required this.matches,
    required this.wins,
    required this.winRate,
  });
}
