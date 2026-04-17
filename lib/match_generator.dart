import 'models/match_record.dart';
import 'models/player.dart';

/// Represents a generated match with two teams.
class GeneratedMatch {
  final List<Player> teamA;
  final List<Player> teamB;
  final String gameMode; // 'singles' or 'doubles'
  final String matchLogic; // 'auto', 'skill', 'history', 'mixed', 'random'

  GeneratedMatch({
    required this.teamA,
    required this.teamB,
    required this.gameMode,
    required this.matchLogic,
  });

  List<Player> get allPlayers => [...teamA, ...teamB];
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
  static const int _maxRecencyLookback = 10;
  static const int _candidateAttempts = 20;

  /// Current DUPR-derived rating used for balancing algorithms.
  static double _ratingWeight(Player player) {
    return player.effectiveDuprRating;
  }

  /// Canonical key for a pair of player IDs (order-independent).
  static String _pairKey(String id1, String id2) {
    return id1.compareTo(id2) < 0 ? '$id1|$id2' : '$id2|$id1';
  }

  /// Build a recency penalty map from recent match history.
  /// More recent matches produce higher penalties so the selector avoids them.
  static Map<String, double> _buildPairPenalties(
    List<MatchRecord> recentMatches,
  ) {
    final penalties = <String, double>{};
    final lookback = recentMatches.length.clamp(0, _maxRecencyLookback);

    for (int i = 0; i < lookback; i++) {
      final match = recentMatches[i];
      final allIds = [
        ...match.teamAPlayerIdList,
        ...match.teamBPlayerIdList,
      ];
      // Most recent match = highest weight
      final weight = (lookback - i).toDouble();

      for (int a = 0; a < allIds.length; a++) {
        for (int b = a + 1; b < allIds.length; b++) {
          final key = _pairKey(allIds[a], allIds[b]);
          penalties[key] = (penalties[key] ?? 0) + weight;
        }
      }
    }

    return penalties;
  }

  /// Score a group of players by how recently they've appeared in the same match.
  static double _groupPenalty(
    List<Player> group,
    Map<String, double> pairPenalties,
  ) {
    double penalty = 0;
    for (int a = 0; a < group.length; a++) {
      for (int b = a + 1; b < group.length; b++) {
        final id1 = group[a].id ?? '';
        final id2 = group[b].id ?? '';
        if (id1.isNotEmpty && id2.isNotEmpty) {
          penalty += pairPenalties[_pairKey(id1, id2)] ?? 0;
        }
      }
    }
    return penalty;
  }

  /// Pick [count] players from [pool] that minimize overlap with recent matches.
  /// Tries [_candidateAttempts] random selections and returns the best one.
  static List<Player> _selectDiverse(
    List<Player> pool,
    int count,
    Map<String, double> pairPenalties,
  ) {
    if (pairPenalties.isEmpty || pool.length <= count) {
      pool.shuffle();
      return pool.take(count).toList();
    }

    List<Player>? best;
    double bestPenalty = double.infinity;

    for (int i = 0; i < _candidateAttempts; i++) {
      pool.shuffle();
      final candidate = pool.take(count).toList();
      final penalty = _groupPenalty(candidate, pairPenalties);

      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        best = List.of(candidate);
        if (penalty == 0) break;
      }
    }

    return best ?? (pool..shuffle()).take(count).toList();
  }

  /// Main entry point.
  /// [playerStandings] is optional and only used for 'history' (Winners & Losers) mode.
  /// [recentMatches] is used to avoid repeating the same player groups.
  static MatchGenerationResult generate({
    required List<Player> availablePlayers,
    required String gameMode,
    required String matchLogic,
    Map<String, Map<String, int>>? playerStandings,
    List<MatchRecord>? recentMatches,
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

    // Sort recent matches by date descending for recency weighting
    final sortedRecent = [...?recentMatches]
      ..sort((a, b) => b.date.compareTo(a.date));
    final pairPenalties = _buildPairPenalties(sortedRecent);

    switch (matchLogic) {
      case 'auto':
        return _autoBalanced(players, gameMode, pairPenalties);
      case 'skill':
        return _skillSeparated(players, gameMode, pairPenalties);
      case 'history':
        return _winnersAndLosers(
          players,
          gameMode,
          playerStandings ?? <String, Map<String, int>>{},
        );
      case 'mixed':
        return _mixedDoubles(players, pairPenalties);
      case 'random':
        return _random(players, gameMode);
      default:
        return _autoBalanced(players, gameMode, pairPenalties);
    }
  }

  /// RANDOM: Purely random player selection, no skill or history consideration.
  static MatchGenerationResult _random(
    List<Player> players,
    String gameMode,
  ) {
    final int requiredCount = gameMode == 'singles' ? 2 : 4;
    final shuffled = List<Player>.from(players)..shuffle();
    final selected = shuffled.take(requiredCount).toList();

    if (gameMode == 'singles') {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [selected[0]],
          teamB: [selected[1]],
          gameMode: gameMode,
          matchLogic: 'random',
        ),
      );
    } else {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [selected[0], selected[1]],
          teamB: [selected[2], selected[3]],
          gameMode: gameMode,
          matchLogic: 'random',
        ),
      );
    }
  }

  /// AUTO-BALANCED: Select players avoiding recent pairings, then balance teams by skill.
  static MatchGenerationResult _autoBalanced(
    List<Player> players,
    String gameMode,
    Map<String, double> pairPenalties,
  ) {
    final int requiredCount = gameMode == 'singles' ? 2 : 4;

    final selected = _selectDiverse(players, requiredCount, pairPenalties);

    // Sort the selected players by skill for balanced team assignment
    selected.sort(
      (a, b) => _ratingWeight(b).compareTo(_ratingWeight(a)),
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

  /// SKILL-SEPARATED: Only players in the same derived DUPR band play together.
  static MatchGenerationResult _skillSeparated(
    List<Player> players,
    String gameMode,
    Map<String, double> pairPenalties,
  ) {
    final int requiredCount = gameMode == 'singles' ? 2 : 4;

    // Group players by derived DUPR label.
    final Map<String, List<Player>> groups = {};
    for (final p in players) {
      groups.putIfAbsent(p.displaySkillLabel, () => []).add(p);
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
        'No DUPR band has $requiredCount+ available players right now.',
      );
    }

    final pool = groups[eligibleSkill]!;
    final selected = _selectDiverse(
      pool,
      requiredCount,
      pairPenalties,
    );

    if (gameMode == 'singles') {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [selected[0]],
          teamB: [selected[1]],
          gameMode: gameMode,
          matchLogic: 'skill',
        ),
      );
    } else {
      return MatchGenerationResult.success(
        GeneratedMatch(
          teamA: [selected[0], selected[1]],
          teamB: [selected[2], selected[3]],
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
  static MatchGenerationResult _mixedDoubles(
    List<Player> players,
    Map<String, double> pairPenalties,
  ) {
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

    // Try multiple male/female combinations, pick least recently paired
    List<Player>? bestGroup;
    double bestPenalty = double.infinity;

    for (int i = 0; i < _candidateAttempts; i++) {
      males.shuffle();
      females.shuffle();
      final group = [males[0], males[1], females[0], females[1]];
      final penalty = _groupPenalty(group, pairPenalties);

      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        bestGroup = List.of(group);
        if (penalty == 0) break;
      }
    }

    if (bestGroup == null) {
      males.shuffle();
      females.shuffle();
      bestGroup = [males[0], males[1], females[0], females[1]];
    }

    final m1 = bestGroup[0], m2 = bestGroup[1];
    final f1 = bestGroup[2], f2 = bestGroup[3];

    // Try both team combinations and pick the most balanced:
    // Option 1: Team A = m1+f1, Team B = m2+f2
    // Option 2: Team A = m1+f2, Team B = m2+f1
    final skill1A = _ratingWeight(m1) + _ratingWeight(f1);
    final skill1B = _ratingWeight(m2) + _ratingWeight(f2);
    final diff1 = (skill1A - skill1B).abs();

    final skill2A = _ratingWeight(m1) + _ratingWeight(f2);
    final skill2B = _ratingWeight(m2) + _ratingWeight(f1);
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
