import 'match.dart';

/// Per-player statistics for a match.
/// Same model for manual input (Phase 1) and CV-generated stats (Phase 3+).
class MatchStats {
  final String? id;
  final String matchId;
  final String playerId;

  // Serve stats
  final int firstServeIn;
  final int firstServeTotal;
  final int secondServeIn;
  final int secondServeTotal;
  final int aces;
  final int doubleFaults;

  // Shot stats
  final int winners;
  final int unforcedErrors;
  final int forcedErrors;

  // Padel-specific shots
  final int bandejaWinners;
  final int viboraWinners;
  final int smashWinners;
  final int lobWinners;
  final int volleyWinners;

  // Net play
  final int netPointsWon;
  final int netPointsTotal;

  // Points
  final int breakPointsWon;
  final int breakPointsTotal;
  final int totalPointsWon;
  final int totalPointsPlayed;

  // Source of stats — key for Phase 3 CV integration
  final StatsInputSource inputSource;

  const MatchStats({
    this.id,
    required this.matchId,
    required this.playerId,
    this.firstServeIn = 0,
    this.firstServeTotal = 0,
    this.secondServeIn = 0,
    this.secondServeTotal = 0,
    this.aces = 0,
    this.doubleFaults = 0,
    this.winners = 0,
    this.unforcedErrors = 0,
    this.forcedErrors = 0,
    this.bandejaWinners = 0,
    this.viboraWinners = 0,
    this.smashWinners = 0,
    this.lobWinners = 0,
    this.volleyWinners = 0,
    this.netPointsWon = 0,
    this.netPointsTotal = 0,
    this.breakPointsWon = 0,
    this.breakPointsTotal = 0,
    this.totalPointsWon = 0,
    this.totalPointsPlayed = 0,
    this.inputSource = StatsInputSource.manual,
  });

  double get firstServePercentage =>
      firstServeTotal > 0 ? firstServeIn / firstServeTotal * 100 : 0;

  double get netPointsPercentage =>
      netPointsTotal > 0 ? netPointsWon / netPointsTotal * 100 : 0;

  int get totalShotWinners =>
      bandejaWinners +
      viboraWinners +
      smashWinners +
      lobWinners +
      volleyWinners;

  MatchStats copyWith({
    String? id,
    String? matchId,
    String? playerId,
    int? firstServeIn,
    int? firstServeTotal,
    int? secondServeIn,
    int? secondServeTotal,
    int? aces,
    int? doubleFaults,
    int? winners,
    int? unforcedErrors,
    int? forcedErrors,
    int? bandejaWinners,
    int? viboraWinners,
    int? smashWinners,
    int? lobWinners,
    int? volleyWinners,
    int? netPointsWon,
    int? netPointsTotal,
    int? breakPointsWon,
    int? breakPointsTotal,
    int? totalPointsWon,
    int? totalPointsPlayed,
    StatsInputSource? inputSource,
  }) {
    return MatchStats(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      firstServeIn: firstServeIn ?? this.firstServeIn,
      firstServeTotal: firstServeTotal ?? this.firstServeTotal,
      secondServeIn: secondServeIn ?? this.secondServeIn,
      secondServeTotal: secondServeTotal ?? this.secondServeTotal,
      aces: aces ?? this.aces,
      doubleFaults: doubleFaults ?? this.doubleFaults,
      winners: winners ?? this.winners,
      unforcedErrors: unforcedErrors ?? this.unforcedErrors,
      forcedErrors: forcedErrors ?? this.forcedErrors,
      bandejaWinners: bandejaWinners ?? this.bandejaWinners,
      viboraWinners: viboraWinners ?? this.viboraWinners,
      smashWinners: smashWinners ?? this.smashWinners,
      lobWinners: lobWinners ?? this.lobWinners,
      volleyWinners: volleyWinners ?? this.volleyWinners,
      netPointsWon: netPointsWon ?? this.netPointsWon,
      netPointsTotal: netPointsTotal ?? this.netPointsTotal,
      breakPointsWon: breakPointsWon ?? this.breakPointsWon,
      breakPointsTotal: breakPointsTotal ?? this.breakPointsTotal,
      totalPointsWon: totalPointsWon ?? this.totalPointsWon,
      totalPointsPlayed: totalPointsPlayed ?? this.totalPointsPlayed,
      inputSource: inputSource ?? this.inputSource,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'match_id': matchId,
        'player_id': playerId,
        'first_serve_in': firstServeIn,
        'first_serve_total': firstServeTotal,
        'second_serve_in': secondServeIn,
        'second_serve_total': secondServeTotal,
        'aces': aces,
        'double_faults': doubleFaults,
        'winners': winners,
        'unforced_errors': unforcedErrors,
        'forced_errors': forcedErrors,
        'bandeja_winners': bandejaWinners,
        'vibora_winners': viboraWinners,
        'smash_winners': smashWinners,
        'lob_winners': lobWinners,
        'volley_winners': volleyWinners,
        'net_points_won': netPointsWon,
        'net_points_total': netPointsTotal,
        'break_points_won': breakPointsWon,
        'break_points_total': breakPointsTotal,
        'total_points_won': totalPointsWon,
        'total_points_played': totalPointsPlayed,
        'input_source': inputSource.name,
      };

  factory MatchStats.fromJson(Map<String, dynamic> json) => MatchStats(
        id: json['id'] as String?,
        matchId: json['match_id'] as String,
        playerId: json['player_id'] as String,
        firstServeIn: json['first_serve_in'] as int? ?? 0,
        firstServeTotal: json['first_serve_total'] as int? ?? 0,
        secondServeIn: json['second_serve_in'] as int? ?? 0,
        secondServeTotal: json['second_serve_total'] as int? ?? 0,
        aces: json['aces'] as int? ?? 0,
        doubleFaults: json['double_faults'] as int? ?? 0,
        winners: json['winners'] as int? ?? 0,
        unforcedErrors: json['unforced_errors'] as int? ?? 0,
        forcedErrors: json['forced_errors'] as int? ?? 0,
        bandejaWinners: json['bandeja_winners'] as int? ?? 0,
        viboraWinners: json['vibora_winners'] as int? ?? 0,
        smashWinners: json['smash_winners'] as int? ?? 0,
        lobWinners: json['lob_winners'] as int? ?? 0,
        volleyWinners: json['volley_winners'] as int? ?? 0,
        netPointsWon: json['net_points_won'] as int? ?? 0,
        netPointsTotal: json['net_points_total'] as int? ?? 0,
        breakPointsWon: json['break_points_won'] as int? ?? 0,
        breakPointsTotal: json['break_points_total'] as int? ?? 0,
        totalPointsWon: json['total_points_won'] as int? ?? 0,
        totalPointsPlayed: json['total_points_played'] as int? ?? 0,
        inputSource: StatsInputSource.values.firstWhere(
          (e) => e.name == (json['input_source'] as String? ?? 'manual'),
          orElse: () => StatsInputSource.manual,
        ),
      );
}
