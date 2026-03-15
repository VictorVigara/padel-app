import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/features/rating/domain/services/elo_calculator.dart';

void main() {
  group('EloCalculator', () {
    test('expected score is 0.5 for equal ratings', () {
      final expected = EloCalculator.expectedScore(1200, 1200);
      expect(expected, closeTo(0.5, 0.001));
    });

    test('higher rated player has higher expected score', () {
      final expected = EloCalculator.expectedScore(1400, 1200);
      expect(expected, greaterThan(0.5));
    });

    test('winner gains rating, loser loses rating', () {
      final newRating = EloCalculator.calculateNewRating(
        playerRating: 1200,
        opponentRating: 1200,
        won: true,
      );
      expect(newRating, greaterThan(1200));

      final loserRating = EloCalculator.calculateNewRating(
        playerRating: 1200,
        opponentRating: 1200,
        won: false,
      );
      expect(loserRating, lessThan(1200));
    });

    test('upset win gives bigger rating change', () {
      // Lower-rated player beats higher-rated
      final upsetGain = EloCalculator.calculateNewRating(
        playerRating: 1000,
        opponentRating: 1400,
        won: true,
      );
      // Expected win gives smaller gain
      final expectedGain = EloCalculator.calculateNewRating(
        playerRating: 1400,
        opponentRating: 1000,
        won: true,
      );
      expect(upsetGain - 1000, greaterThan(expectedGain - 1400));
    });

    test('straight sets win gives higher K factor', () {
      final straightSets = EloCalculator.calculateNewRating(
        playerRating: 1200,
        opponentRating: 1200,
        won: true,
        totalSetsPlayed: 2,
        totalSetsInFormat: 3,
      );
      final fullMatch = EloCalculator.calculateNewRating(
        playerRating: 1200,
        opponentRating: 1200,
        won: true,
        totalSetsPlayed: 3,
        totalSetsInFormat: 3,
      );
      expect(straightSets, greaterThan(fullMatch));
    });

    test('team rating is average of two players', () {
      expect(EloCalculator.teamRating(1000, 1400), equals(1200));
    });
  });
}
