import 'package:padel_app/features/match/domain/models/match.dart';
import 'package:padel_app/features/rating/data/repositories/rating_repository.dart';
import 'package:padel_app/features/rating/domain/models/rating_record.dart';
import 'package:padel_app/features/rating/domain/services/elo_calculator.dart';

class RatingService {
  final RatingRepository _ratingRepository;

  RatingService(this._ratingRepository);

  /// Calculate ELO after a new match and save the rating record.
  ///
  /// [opponentIds] — profile IDs of registered opponents. When provided,
  /// their real ratings are used instead of the default 1200. Rating records
  /// are also created for registered opponents.
  ///
  /// Returns the rating change for the current user.
  Future<double> calculateAndSaveRating({
    required String userId,
    required PadelMatch match,
    List<String> opponentIds = const [],
  }) async {
    final latest = await _ratingRepository.getLatestRating(userId);
    final currentRating = latest?.rating ?? EloCalculator.startingRating;

    // Resolve opponent rating — use real ratings when available
    final opponentRating = await _resolveOpponentRating(opponentIds);

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

    // Also update registered opponents' ratings
    for (final oppId in opponentIds) {
      await _saveOpponentRating(
        opponentId: oppId,
        playerRating: currentRating,
        won: !won, // opponent's result is opposite
        match: match,
      );
    }

    return ratingChange;
  }

  /// Resolve the effective opponent rating from a list of opponent IDs.
  /// For doubles (2 opponents), uses team average.
  /// Falls back to 1200 for unregistered opponents.
  Future<double> _resolveOpponentRating(List<String> opponentIds) async {
    if (opponentIds.isEmpty) return EloCalculator.startingRating;

    final ratings = <double>[];
    for (final id in opponentIds) {
      final latest = await _ratingRepository.getLatestRating(id);
      ratings.add(latest?.rating ?? EloCalculator.startingRating);
    }

    if (ratings.length == 1) return ratings.first;
    return EloCalculator.teamRating(ratings[0], ratings[1]);
  }

  /// Save a rating record for a registered opponent.
  Future<void> _saveOpponentRating({
    required String opponentId,
    required double playerRating,
    required bool won,
    required PadelMatch match,
  }) async {
    final latest = await _ratingRepository.getLatestRating(opponentId);
    final oppRating = latest?.rating ?? EloCalculator.startingRating;

    final totalSetsPlayed = match.setScores.length;
    final totalSetsInFormat = _maxSetsForFormat(match.matchFormat);

    final newRating = EloCalculator.calculateNewRating(
      playerRating: oppRating,
      opponentRating: playerRating,
      won: won,
      totalSetsPlayed: totalSetsPlayed,
      totalSetsInFormat: totalSetsInFormat,
    );

    final ratingChange = newRating - oppRating;

    await _ratingRepository.insertRating(RatingRecord(
      playerId: opponentId,
      rating: newRating,
      ratingChange: ratingChange,
      matchId: match.id,
      calculatedAt: DateTime.now(),
    ));
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
