import 'dart:math';

/// Pure Dart ELO rating calculator for padel.
/// This logic is mirrored in the Supabase Edge Function for server-side authority.
class EloCalculator {
  static const double defaultKFactor = 32.0;
  static const double startingRating = 1200.0;

  /// Calculate expected score for a player given their rating and opponent's rating.
  static double expectedScore(double playerRating, double opponentRating) {
    return 1.0 / (1.0 + pow(10.0, (opponentRating - playerRating) / 400.0));
  }

  /// Calculate new rating after a match.
  ///
  /// [playerRating] - current rating of the player/team
  /// [opponentRating] - current rating of the opponent/team
  /// [won] - whether the player won
  /// [totalSetsPlayed] - how many sets were actually played
  /// [totalSetsInFormat] - max sets in the format (e.g., 3 for best_of_3)
  static double calculateNewRating({
    required double playerRating,
    required double opponentRating,
    required bool won,
    int? totalSetsPlayed,
    int? totalSetsInFormat,
  }) {
    final expected = expectedScore(playerRating, opponentRating);
    final actual = won ? 1.0 : 0.0;

    // Score margin adjustment
    var k = defaultKFactor;
    if (totalSetsPlayed != null && totalSetsInFormat != null) {
      if (totalSetsPlayed < totalSetsInFormat) {
        // Straight sets win — slightly higher K
        k *= 1.1;
      } else {
        // Went to max sets — close match, lower adjustment
        k *= 0.95;
      }
    }

    return playerRating + k * (actual - expected);
  }

  /// For doubles: team rating is the average of both players.
  static double teamRating(double player1Rating, double player2Rating) {
    return (player1Rating + player2Rating) / 2.0;
  }
}
