class RatingRecord {
  final String? id;
  final String playerId;
  final double rating;
  final double ratingChange;
  final String? matchId;
  final DateTime calculatedAt;

  const RatingRecord({
    this.id,
    required this.playerId,
    required this.rating,
    required this.ratingChange,
    this.matchId,
    required this.calculatedAt,
  });

  factory RatingRecord.fromJson(Map<String, dynamic> json) => RatingRecord(
        id: json['id'] as String?,
        playerId: json['player_id'] as String,
        rating: (json['rating'] as num).toDouble(),
        ratingChange: (json['rating_change'] as num?)?.toDouble() ?? 0.0,
        matchId: json['match_id'] as String?,
        calculatedAt: DateTime.parse(json['calculated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'player_id': playerId,
        'rating': rating,
        'rating_change': ratingChange,
        'match_id': matchId,
        'calculated_at': calculatedAt.toIso8601String(),
      };
}
