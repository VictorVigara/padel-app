/// Represents a set score in a padel match.
class SetScore {
  final int team1Games;
  final int team2Games;

  const SetScore({required this.team1Games, required this.team2Games});

  factory SetScore.fromJson(Map<String, dynamic> json) => SetScore(
        team1Games: json['team1'] as int,
        team2Games: json['team2'] as int,
      );

  Map<String, dynamic> toJson() => {
        'team1': team1Games,
        'team2': team2Games,
      };

  @override
  String toString() => '$team1Games-$team2Games';
}

/// Input source for match statistics — supports manual entry and future CV.
enum StatsInputSource { manual, cvAuto, cvReviewed }

/// Match lifecycle status — mirrors the `status` column in the DB.
enum MatchStatus { draft, recording, processing, completed }

/// Core match model. Designed to work identically whether stats come from
/// manual input (Phase 1) or computer vision (Phase 3+).
class PadelMatch {
  final String? id;
  final String createdBy;
  final DateTime matchDate;
  final String? location;
  final String? courtSurface; // glass, cement, turf, other
  final String? matchType; // friendly, league, tournament — nullable for draft matches
  final String? matchFormat; // best_of_3, best_of_5, single_set — nullable for draft matches
  final String? team1Player1Id; // nullable for draft matches
  final String? team1Player2Id;
  final String? team2Player1Id; // nullable for draft matches
  final String? team2Player2Id;
  final int? winnerTeam; // 1 or 2
  final bool isCompleted;
  final MatchStatus status;
  final List<SetScore> setScores;
  final String? videoUrl; // Phase 3+
  final String? leagueId; // Phase 2+
  final String? notes;
  final DateTime? createdAt;

  const PadelMatch({
    this.id,
    required this.createdBy,
    required this.matchDate,
    this.location,
    this.courtSurface,
    this.matchType,
    this.matchFormat,
    this.team1Player1Id,
    this.team1Player2Id,
    this.team2Player1Id,
    this.team2Player2Id,
    this.winnerTeam,
    this.isCompleted = false,
    this.status = MatchStatus.draft,
    this.setScores = const [],
    this.videoUrl,
    this.leagueId,
    this.notes,
    this.createdAt,
  });

  PadelMatch copyWith({
    String? id,
    String? createdBy,
    DateTime? matchDate,
    String? location,
    String? courtSurface,
    String? matchType,
    String? matchFormat,
    String? team1Player1Id,
    String? team1Player2Id,
    String? team2Player1Id,
    String? team2Player2Id,
    int? winnerTeam,
    bool? isCompleted,
    MatchStatus? status,
    List<SetScore>? setScores,
    String? videoUrl,
    String? leagueId,
    String? notes,
  }) {
    return PadelMatch(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      matchDate: matchDate ?? this.matchDate,
      location: location ?? this.location,
      courtSurface: courtSurface ?? this.courtSurface,
      matchType: matchType ?? this.matchType,
      matchFormat: matchFormat ?? this.matchFormat,
      team1Player1Id: team1Player1Id ?? this.team1Player1Id,
      team1Player2Id: team1Player2Id ?? this.team1Player2Id,
      team2Player1Id: team2Player1Id ?? this.team2Player1Id,
      team2Player2Id: team2Player2Id ?? this.team2Player2Id,
      winnerTeam: winnerTeam ?? this.winnerTeam,
      isCompleted: isCompleted ?? this.isCompleted,
      status: status ?? this.status,
      setScores: setScores ?? this.setScores,
      videoUrl: videoUrl ?? this.videoUrl,
      leagueId: leagueId ?? this.leagueId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'created_by': createdBy,
        'match_date': matchDate.toIso8601String(),
        'location': location,
        'court_surface': courtSurface,
        'match_type': matchType,
        'match_format': matchFormat,
        'team1_player1_id': team1Player1Id,
        'team1_player2_id': team1Player2Id,
        'team2_player1_id': team2Player1Id,
        'team2_player2_id': team2Player2Id,
        'winner_team': winnerTeam,
        'is_completed': isCompleted,
        'status': status.name,
        'set_scores': setScores.map((s) => s.toJson()).toList(),
        'video_url': videoUrl,
        'league_id': leagueId,
        'notes': notes,
      };

  factory PadelMatch.fromJson(Map<String, dynamic> json) => PadelMatch(
        id: json['id'] as String?,
        createdBy: json['created_by'] as String,
        matchDate: DateTime.parse(json['match_date'] as String),
        location: json['location'] as String?,
        courtSurface: json['court_surface'] as String?,
        matchType: json['match_type'] as String?,
        matchFormat: json['match_format'] as String?,
        team1Player1Id: json['team1_player1_id'] as String?,
        team1Player2Id: json['team1_player2_id'] as String?,
        team2Player1Id: json['team2_player1_id'] as String?,
        team2Player2Id: json['team2_player2_id'] as String?,
        winnerTeam: json['winner_team'] as int?,
        isCompleted: json['is_completed'] as bool? ?? false,
        status: MatchStatus.values.byName(
          json['status'] as String? ?? 'completed',
        ),
        setScores: (json['set_scores'] as List<dynamic>?)
                ?.map((s) => SetScore.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        videoUrl: json['video_url'] as String?,
        leagueId: json['league_id'] as String?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}
