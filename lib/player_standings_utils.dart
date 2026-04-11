import 'dupr_rating_engine.dart';
import 'models/match_record.dart';
import 'models/player.dart';

List<Map<String, dynamic>> buildPlayerStandings({
  required List<Player> players,
  required List<MatchRecord> matches,
}) {
  final sortedMatches = [...matches]..sort((a, b) => b.date.compareTo(a.date));
  final ratedPlayers = applyDerivedDuprRatingsToPlayers(
    players: players,
    matches: matches,
  );
  final stats = <String, Map<String, dynamic>>{};
  final resultHistory = <String, List<String>>{};
  final partnerChemistry = <String, Map<String, Map<String, dynamic>>>{};

  for (final player in ratedPlayers) {
    if (player.id == null) {
      continue;
    }

    stats[player.id!] = {
      'player': player,
      'wins': 0,
      'losses': 0,
      'matchesPlayed': 0,
      'winPercent': 0.0,
      'currentStreak': 0,
      'streakLabel': '-',
      'recentResults': <String>[],
      'recentFormScore': 0.0,
      'bestPartnerName': null,
      'bestPartnerWins': 0,
      'bestPartnerGames': 0,
      'bestPartnerWinPercent': 0.0,
    };
    resultHistory[player.id!] = <String>[];
    partnerChemistry[player.id!] = <String, Map<String, dynamic>>{};
  }

  for (final match in sortedMatches) {
    final winningIds = match.winnerPlayerIds;
    final losingIds = match.loserPlayerIds;

    for (final id in winningIds) {
      if (!stats.containsKey(id)) {
        continue;
      }

      stats[id]!['wins'] = (stats[id]!['wins'] as int) + 1;
      stats[id]!['matchesPlayed'] = (stats[id]!['matchesPlayed'] as int) + 1;
      resultHistory[id]!.add('W');
    }

    for (final id in losingIds) {
      if (!stats.containsKey(id)) {
        continue;
      }

      stats[id]!['losses'] = (stats[id]!['losses'] as int) + 1;
      stats[id]!['matchesPlayed'] = (stats[id]!['matchesPlayed'] as int) + 1;
      resultHistory[id]!.add('L');
    }

    if (match.gameMode != 'doubles') {
      continue;
    }

    _trackPartnerChemistry(
      stats: stats,
      chemistry: partnerChemistry,
      playerIds: match.teamAPlayerIdList,
      playerNames: match.teamAPlayerNameList,
      didWin: match.winningSide == 'A',
    );
    _trackPartnerChemistry(
      stats: stats,
      chemistry: partnerChemistry,
      playerIds: match.teamBPlayerIdList,
      playerNames: match.teamBPlayerNameList,
      didWin: match.winningSide == 'B',
    );
  }

  final results = stats.values.toList();
  for (final standing in results) {
    final player = standing['player'] as Player;
    final playerId = player.id;
    if (playerId == null) {
      continue;
    }

    final wins = standing['wins'] as int;
    final matchesPlayed = standing['matchesPlayed'] as int;
    standing['winPercent'] = matchesPlayed > 0
        ? (wins / matchesPlayed * 100.0)
        : 0.0;

    final recentResults = resultHistory[playerId]!.take(5).toList();
    standing['recentResults'] = recentResults;
    standing['recentFormScore'] = recentResults.isEmpty
        ? 0.0
        : (recentResults.where((result) => result == 'W').length /
                  recentResults.length) *
              100.0;

    var streak = 0;
    for (final result in resultHistory[playerId]!) {
      if (streak == 0) {
        streak = result == 'W' ? 1 : -1;
        continue;
      }

      if (streak > 0 && result == 'W') {
        streak += 1;
      } else if (streak < 0 && result == 'L') {
        streak -= 1;
      } else {
        break;
      }
    }

    standing['currentStreak'] = streak;
    standing['streakLabel'] = streak == 0
        ? '-'
        : '${streak > 0 ? 'W' : 'L'}${streak.abs()}';

    final chemistry = partnerChemistry[playerId]!.values.toList();
    for (final partner in chemistry) {
      final games = partner['games'] as int;
      final partnerWins = partner['wins'] as int;
      partner['winPercent'] = games > 0 ? (partnerWins / games * 100.0) : 0.0;
    }

    chemistry.sort((a, b) {
      final byPercent = (b['winPercent'] as double).compareTo(
        a['winPercent'] as double,
      );
      if (byPercent != 0) {
        return byPercent;
      }

      final byWins = (b['wins'] as int).compareTo(a['wins'] as int);
      if (byWins != 0) {
        return byWins;
      }

      final byGames = (b['games'] as int).compareTo(a['games'] as int);
      if (byGames != 0) {
        return byGames;
      }

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    if (chemistry.isNotEmpty) {
      final bestPartner = chemistry.first;
      standing['bestPartnerName'] = bestPartner['name'];
      standing['bestPartnerWins'] = bestPartner['wins'];
      standing['bestPartnerGames'] = bestPartner['games'];
      standing['bestPartnerWinPercent'] = bestPartner['winPercent'];
    }
  }

  results.sort((a, b) {
    final byWinPercent = (b['winPercent'] as double).compareTo(
      a['winPercent'] as double,
    );
    if (byWinPercent != 0) {
      return byWinPercent;
    }

    return (b['wins'] as int).compareTo(a['wins'] as int);
  });

  return results;
}

void _trackPartnerChemistry({
  required Map<String, Map<String, dynamic>> stats,
  required Map<String, Map<String, Map<String, dynamic>>> chemistry,
  required List<String> playerIds,
  required List<String> playerNames,
  required bool didWin,
}) {
  for (var index = 0; index < playerIds.length; index++) {
    final playerId = playerIds[index];
    if (!stats.containsKey(playerId)) {
      continue;
    }

    for (
      var partnerIndex = 0;
      partnerIndex < playerIds.length;
      partnerIndex++
    ) {
      if (partnerIndex == index) {
        continue;
      }

      final partnerId = playerIds[partnerIndex];
      final partnerName = partnerIndex < playerNames.length
          ? playerNames[partnerIndex]
          : 'Partner';
      final playerChemistry = chemistry[playerId]!;
      final partnerStats = playerChemistry.putIfAbsent(partnerId, () {
        return {'name': partnerName, 'wins': 0, 'games': 0, 'winPercent': 0.0};
      });

      partnerStats['games'] = (partnerStats['games'] as int) + 1;
      if (didWin) {
        partnerStats['wins'] = (partnerStats['wins'] as int) + 1;
      }
    }
  }
}
