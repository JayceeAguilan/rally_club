import 'dupr_rating.dart';
import 'models/match_record.dart';
import 'models/player.dart';

class PlayerDuprSnapshot {
  const PlayerDuprSnapshot({
    required this.rating,
    required this.ratedMatches,
    this.updatedAt,
  });

  final double rating;
  final int ratedMatches;
  final String? updatedAt;
}

Map<String, PlayerDuprSnapshot> replayDuprRatings({
  required List<Player> players,
  required List<MatchRecord> matches,
}) {
  final trackedPlayerIds = <String>{
    for (final player in players)
      if (player.id != null && !player.isGuest) player.id!,
  };

  final ratings = <String, double>{
    for (final playerId in trackedPlayerIds) playerId: DuprRating.baselineRating,
  };
  final ratedMatches = <String, int>{
    for (final playerId in trackedPlayerIds) playerId: 0,
  };

  final sortedMatches = [...matches]
    ..sort((a, b) => a.date.compareTo(b.date));

  for (final match in sortedMatches) {
    final teamAContext = _buildTeamContext(
      ids: match.teamAPlayerIdList,
      snapshotRatings: match.teamAPlayerRatingList,
      currentRatings: ratings,
    );
    final teamBContext = _buildTeamContext(
      ids: match.teamBPlayerIdList,
      snapshotRatings: match.teamBPlayerRatingList,
      currentRatings: ratings,
    );

    if (teamAContext.isEmpty || teamBContext.isEmpty) {
      continue;
    }

    final teamAAverage = _average(teamAContext.values);
    final teamBAverage = _average(teamBContext.values);

    _applyResult(
      participantIds: match.teamAPlayerIdList,
      didWin: match.winningSide == 'A',
      opponentAverage: teamBAverage,
      trackedPlayerIds: trackedPlayerIds,
      ratings: ratings,
      ratedMatches: ratedMatches,
    );
    _applyResult(
      participantIds: match.teamBPlayerIdList,
      didWin: match.winningSide == 'B',
      opponentAverage: teamAAverage,
      trackedPlayerIds: trackedPlayerIds,
      ratings: ratings,
      ratedMatches: ratedMatches,
    );
  }

  final lastUpdatedAt = sortedMatches.isEmpty ? null : sortedMatches.last.date;
  return {
    for (final playerId in trackedPlayerIds)
      playerId: PlayerDuprSnapshot(
        rating: ratings[playerId] ?? DuprRating.baselineRating,
        ratedMatches: ratedMatches[playerId] ?? 0,
        updatedAt: lastUpdatedAt,
      ),
  };
}

List<Player> applyDerivedDuprRatingsToPlayers({
  required List<Player> players,
  required List<MatchRecord> matches,
}) {
  final replayedRatings = replayDuprRatings(players: players, matches: matches);

  return players.map((player) {
    final playerId = player.id;
    if (playerId == null || !replayedRatings.containsKey(playerId)) {
      return player;
    }

    final snapshot = replayedRatings[playerId]!;
    return player.copyWith(
      duprRating: snapshot.rating,
      duprMatchesPlayed: snapshot.ratedMatches,
      duprLastUpdatedAt: snapshot.updatedAt,
    );
  }).toList();
}

Map<String, double> _buildTeamContext({
  required List<String> ids,
  required List<double> snapshotRatings,
  required Map<String, double> currentRatings,
}) {
  final context = <String, double>{};
  for (var index = 0; index < ids.length; index++) {
    final playerId = ids[index];
    final currentRating = currentRatings[playerId];
    final snapshotRating = index < snapshotRatings.length
        ? snapshotRatings[index]
        : DuprRating.baselineRating;
    context[playerId] = currentRating ?? snapshotRating;
  }
  return context;
}

void _applyResult({
  required List<String> participantIds,
  required bool didWin,
  required double opponentAverage,
  required Set<String> trackedPlayerIds,
  required Map<String, double> ratings,
  required Map<String, int> ratedMatches,
}) {
  for (final playerId in participantIds) {
    if (!trackedPlayerIds.contains(playerId)) {
      continue;
    }

    final currentRating = ratings[playerId] ?? DuprRating.baselineRating;
    final currentRatedMatches = ratedMatches[playerId] ?? 0;
    final delta = DuprRating.ratingDelta(
      playerRating: currentRating,
      opponentRating: opponentAverage,
      didWin: didWin,
      ratedMatches: currentRatedMatches,
    );

    ratings[playerId] = DuprRating.normalizeRating(currentRating + delta);
    ratedMatches[playerId] = currentRatedMatches + 1;
  }
}

double _average(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) {
    return DuprRating.baselineRating;
  }

  final sum = list.fold<double>(0.0, (total, value) => total + value);
  return DuprRating.normalizeRating(sum / list.length);
}