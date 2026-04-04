import 'models/player.dart';

/// Represents a generated match with two teams.
class GeneratedMatch {
  final List<Player> teamA;
  final List<Player> teamB;
  final String gameMode; // 'singles' or 'doubles'
  final String matchLogic; // 'auto', 'skill', 'history', 'mixed'

  GeneratedMatch({
    required this.teamA,
    required this.teamB,
    required this.gameMode,
    required this.matchLogic,
  });
}

/// Result wrapper that includes validation info.
class MatchGenerationResult {
  final GeneratedMatch? match;
  final String? error;

  bool get isSuccess => match != null;

  MatchGenerationResult.success(this.match) : error = null;
  MatchGenerationResult.failure(this.error) : match = null;
}

class MatchGenerator {
  /// Skill weight mapping for balancing algorithms.
  static int _skillWeight(String skillLevel) {
    switch (Player.normalizeSkillLevelCode(skillLevel)) {
      case 'Beg':
        return 1;
      case 'Int':
        return 2;
      case 'Adv':
        return 3;
      default:
        return 2;
    }
  }

  /// Main entry point.
  /// [playerStandings] is optional and only used for 'history' (Winners & Losers) mode.
  /// It should be a map of playerId → { 'wins': int, 'losses': int }.
  static MatchGenerationResult generate({
    required List<Player> availablePlayers,
    required String gameMode,
    required String matchLogic,
    Map<String, Map<String, int>>? playerStandings,
  }) {
    // Filter to only available players
    final players = availablePlayers.where((p) => p.isAvailable).toList();

    final int requiredCount = gameMode == 'singles' ? 2 : 4;

    // Block Mixed Doubles in Singles mode
    if (matchLogic == 'mixed' && gameMode == 'singles') {
      return MatchGenerationResult.failure(
        'Mixed Doubles is only available in Doubles mode.',
      );
    }

    if (players.length < requiredCount) {
      return MatchGenerationResult.failure(
        'Need at least $requiredCount available players. Currently have ${players.length}.',
      );
    }

    switch (matchLogic) {
      case 'auto':
        return _autoBalanced(players, gameMode);
      case 'skill':
        return _skillSeparated(players, gameMode);
      case 'history':
        return _winnersAndLosers(
          players,
          gameMode,
          playerStandings ?? <String, Map<String, int>>{},
        );
      case 'mixed':
        return _mixedDoubles(players);
      default:
        return _autoBalanced(players, gameMode);
    }
  }

  /// AUTO-BALANCED: Randomly select players, then balance teams by skill weight.
  static MatchGenerationResult _autoBalanced(
    List<Player> players,
    String gameMode,
  ) {
    final int requiredCount = gameMode == 'singles' ? 2 : 4;

    // Shuffle the entire pool for true randomness
    players.shuffle();

    // Randomly pick the required number of players
    final selected = players.take(requiredCount).toList();

    // Sort the selected players by skill for balanced team assignment
    selected.sort(
      (a, b) =>
          _skillWeight(b.skillLevel).compareTo(_skillWeight(a.skillLevel)),
    );

    if (gameMode == 'singles') {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [selected[0]],
          teamB: [selected[1]],
          gameMode: gameMode,
          matchLogic: 'auto',
        ),
      );
    } else {
      // Doubles: Snake draft — strongest + weakest vs 2nd + 3rd
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [selected[0], selected[3]], // Strongest + weakest
          teamB: [selected[1], selected[2]], // 2nd + 3rd
          gameMode: gameMode,
          matchLogic: 'auto',
        ),
      );
    }
  }

  /// SKILL-SEPARATED: Only players of the same skill level play together.
  static MatchGenerationResult _skillSeparated(
    List<Player> players,
    String gameMode,
  ) {
    final int requiredCount = gameMode == 'singles' ? 2 : 4;

    // Group players by skill level
    final Map<String, List<Player>> groups = {};
    for (final p in players) {
      groups
          .putIfAbsent(Player.normalizeSkillLevelCode(p.skillLevel), () => [])
          .add(p);
    }

    // Find the first group with enough players
    String? eligibleSkill;
    for (final entry in groups.entries) {
      if (entry.value.length >= requiredCount) {
        eligibleSkill = entry.key;
        break;
      }
    }

    if (eligibleSkill == null) {
      return MatchGenerationResult.failure(
        'No skill group has $requiredCount+ available players of the same level.',
      );
    }

    final pool = groups[eligibleSkill]!;
    pool.shuffle();

    if (gameMode == 'singles') {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [pool[0]],
          teamB: [pool[1]],
          gameMode: gameMode,
          matchLogic: 'skill',
        ),
      );
    } else {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [pool[0], pool[1]],
          teamB: [pool[2], pool[3]],
          gameMode: gameMode,
          matchLogic: 'skill',
        ),
      );
    }
  }

  /// WINNERS AND LOSERS: Sort by win record from match history.
  /// Winners play winners, losers play losers. Creates natural skill sorting.
  static MatchGenerationResult _winnersAndLosers(
    List<Player> players,
    String gameMode,
    Map<String, Map<String, int>> standings,
  ) {
    // Sort players by wins descending (winners at top, losers at bottom)
    // Players with no match history go in the middle
    players.shuffle(); // Randomize first for ties
    players.sort((a, b) {
      final aWins = standings[a.id]?['wins'] ?? 0;
      final bWins = standings[b.id]?['wins'] ?? 0;
      final aLosses = standings[a.id]?['losses'] ?? 0;
      final bLosses = standings[b.id]?['losses'] ?? 0;

      // Sort by net wins (wins - losses) descending
      final aNet = aWins - aLosses;
      final bNet = bWins - bLosses;
      return bNet.compareTo(aNet);
    });

    if (gameMode == 'singles') {
      // Top 2 winners play each other
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [players[0]],
          teamB: [players[1]],
          gameMode: gameMode,
          matchLogic: 'history',
        ),
      );
    } else {
      // Top 2 winners team up, bottom 2 team up
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [players[0], players[1]], // Winners team
          teamB: [players[2], players[3]], // Losers team
          gameMode: gameMode,
          matchLogic: 'history',
        ),
      );
    }
  }

  /// MIXED DOUBLES: Each team must have 1 male and 1 female. Doubles only.
  /// Also tries to balance combined skill totals between teams.
  static MatchGenerationResult _mixedDoubles(List<Player> players) {
    final males = players.where((p) => p.gender == 'Male').toList();
    final females = players.where((p) => p.gender == 'Female').toList();

    if (males.length < 2) {
      return MatchGenerationResult.failure(
        'Mixed doubles requires at least 2 male and 2 female available players. Currently have ${males.length} male.',
      );
    }

    if (females.length < 2) {
      return MatchGenerationResult.failure(
        'Mixed doubles requires at least 2 male and 2 female available players. Currently have ${females.length} female.',
      );
    }

    males.shuffle();
    females.shuffle();

    // Pick 2 males and 2 females
    final m1 = males[0], m2 = males[1];
    final f1 = females[0], f2 = females[1];

    // Try both team combinations and pick the most balanced:
    // Option 1: Team A = m1+f1, Team B = m2+f2
    // Option 2: Team A = m1+f2, Team B = m2+f1
    final skill1A = _skillWeight(m1.skillLevel) + _skillWeight(f1.skillLevel);
    final skill1B = _skillWeight(m2.skillLevel) + _skillWeight(f2.skillLevel);
    final diff1 = (skill1A - skill1B).abs();

    final skill2A = _skillWeight(m1.skillLevel) + _skillWeight(f2.skillLevel);
    final skill2B = _skillWeight(m2.skillLevel) + _skillWeight(f1.skillLevel);
    final diff2 = (skill2A - skill2B).abs();

    if (diff2 < diff1) {
      // Option 2 is more balanced
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [m1, f2],
          teamB: [m2, f1],
          gameMode: 'doubles',
          matchLogic: 'mixed',
        ),
      );
    }

    return MatchGenerationResult.success(
      GeneratedMatch(
        teamA: [m1, f1],
        teamB: [m2, f2],
        gameMode: 'doubles',
        matchLogic: 'mixed',
      ),
    );
  }
}
