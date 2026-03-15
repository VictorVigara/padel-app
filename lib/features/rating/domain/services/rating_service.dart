import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/rating/data/repositories/rating_repository.dart';
import 'package:padel_app/features/rating/domain/models/rating_record.dart';
import 'package:padel_app/features/rating/domain/services/elo_calculator.dart';

class RatingService {
  final RatingRepository _ratingRepository;

  RatingService(this._ratingRepository);

  /// Calculate ELO after a new match and save the rating record.
  /// Returns the rating change (positive or negative).
  Future<double> calculateAndSaveRating({
    required String userId,
    required PadelMatch match,
  }) async {
    final latest = await _ratingRepository.getLatestRating(userId);
    final currentRating = latest?.rating ?? EloCalculator.startingRating;

    // MVP: opponent rating defaults to 1200 (no player directory yet)
    const opponentRating = EloCalculator.startingRating;

    final won = match.winnerTeam == 1;
    final totalSetsPlayed = match.setScores.length;
    final totalSetsInFormat = _maxSetsForFormat(match.matchFormat);

    final newRating = EloCalculator.calculateNewRating(
      playerRating: currentRating,
      opponentRating: opponentRating,
      won: won,
      totalSetsPlayed: totalSetsPlayed,
      totalSetsInFormat: totalSetsInFormat,
    );

    final ratingChange = newRating - currentRating;

    await _ratingRepository.insertRating(RatingRecord(
      playerId: userId,
      rating: newRating,
      ratingChange: ratingChange,
      matchId: match.id,
      calculatedAt: DateTime.now(),
    ));

    return ratingChange;
  }

  int _maxSetsForFormat(String format) {
    switch (format) {
      case 'best_of_3':
        return 3;
      case 'best_of_5':
        return 5;
      case 'single_set':
        return 1;
      default:
        return 3;
    }
  }
}
