import 'dart:math' as math;

class DuprRating {
  static const double baselineRating = 2.0;
  static const double minimumRating = 2.0;
  static const double maximumRating = 8.0;
  static const double _ratingScale = 0.75;

  static const List<String> filterLabels = [
    'All',
    'Unrated',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static double normalizeRating(num? value) {
    final rawValue = value?.toDouble() ?? baselineRating;
    final clamped = rawValue.clamp(minimumRating, maximumRating);
    return (clamped * 100).roundToDouble() / 100;
  }

  static bool isRated(int ratedMatches) => ratedMatches > 0;

  static String labelForRating({
    required double rating,
    required int ratedMatches,
  }) {
    if (!isRated(ratedMatches)) {
      return 'Unrated';
    }

    final normalizedRating = normalizeRating(rating);
    if (normalizedRating < 3.0) {
      return 'Beginner';
    }
    if (normalizedRating < 4.5) {
      return 'Intermediate';
    }
    return 'Advanced';
  }

  static bool matchesFilter({
    required String filter,
    required String currentLabel,
  }) {
    final normalizedFilter = filter.trim().toLowerCase();
    if (normalizedFilter == 'all' || normalizedFilter == 'all levels') {
      return true;
    }

    return currentLabel.trim().toLowerCase() == normalizedFilter;
  }

  static double expectedScore({
    required double playerRating,
    required double opponentRating,
  }) {
    final normalizedPlayer = normalizeRating(playerRating);
    final normalizedOpponent = normalizeRating(opponentRating);
    final exponent = (normalizedOpponent - normalizedPlayer) / _ratingScale;
    return 1.0 / (1.0 + math.pow(10, exponent));
  }

  static double kFactorForMatches(int ratedMatches) {
    if (ratedMatches < 5) {
      return 0.18;
    }
    if (ratedMatches < 15) {
      return 0.14;
    }
    return 0.1;
  }

  static double ratingDelta({
    required double playerRating,
    required double opponentRating,
    required bool didWin,
    required int ratedMatches,
  }) {
    final expected = expectedScore(
      playerRating: playerRating,
      opponentRating: opponentRating,
    );
    final actual = didWin ? 1.0 : 0.0;
    final rawDelta = kFactorForMatches(ratedMatches) * (actual - expected);
    return (rawDelta * 100).roundToDouble() / 100;
  }

  static String formatRating(double rating) {
    return normalizeRating(rating).toStringAsFixed(2);
  }
}