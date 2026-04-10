List<String> _splitCsvValues(String value) {
  return value
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

class MatchRecord {
  final String? id;
  final String gameMode; // 'singles' or 'doubles'
  final String matchLogic; // 'auto', 'skill', 'history', 'mixed'
  final String teamAPlayerIds; // Comma-separated player IDs: "1,2"
  final String teamBPlayerIds; // Comma-separated player IDs: "3,4"
  final String teamANames; // Comma-separated names: "Jaycee,James"
  final String teamBNames; // Comma-separated names: "David,Elena"
  final String winningSide; // 'A' or 'B'
  final String date; // ISO 8601 datetime string
  final String? clubId;
  final String? createdByUid;

  MatchRecord({
    this.id,
    required this.gameMode,
    required this.matchLogic,
    required this.teamAPlayerIds,
    required this.teamBPlayerIds,
    required this.teamANames,
    required this.teamBNames,
    required this.winningSide,
    required this.date,
    this.clubId,
    this.createdByUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameMode': gameMode,
      'matchLogic': matchLogic,
      'teamAPlayerIds': teamAPlayerIds,
      'teamBPlayerIds': teamBPlayerIds,
      'teamANames': teamANames,
      'teamBNames': teamBNames,
      'winningSide': winningSide,
      'date': date,
      'clubId': clubId,
      'createdByUid': createdByUid,
    };
  }

  factory MatchRecord.fromMap(Map<String, dynamic> map) {
    return MatchRecord(
      id: map['id'],
      gameMode: map['gameMode'],
      matchLogic: map['matchLogic'],
      teamAPlayerIds: map['teamAPlayerIds'],
      teamBPlayerIds: map['teamBPlayerIds'],
      teamANames: map['teamANames'],
      teamBNames: map['teamBNames'],
      winningSide: map['winningSide'],
      date: map['date'],
      clubId: map['clubId'],
      createdByUid: map['createdByUid'],
    );
  }

  List<String> get teamAPlayerIdList => _splitCsvValues(teamAPlayerIds);

  List<String> get teamBPlayerIdList => _splitCsvValues(teamBPlayerIds);

  List<String> get teamAPlayerNameList => _splitCsvValues(teamANames);

  List<String> get teamBPlayerNameList => _splitCsvValues(teamBNames);

  /// Get the list of winning player IDs.
  List<String> get winnerPlayerIds {
    return winningSide == 'A' ? teamAPlayerIdList : teamBPlayerIdList;
  }

  /// Get the list of losing player IDs.
  List<String> get loserPlayerIds {
    return winningSide == 'A' ? teamBPlayerIdList : teamAPlayerIdList;
  }

  /// Human-readable winning team names.
  String get winnerNames => winningSide == 'A' ? teamANames : teamBNames;

  /// Human-readable losing team names.
  String get loserNames => winningSide == 'A' ? teamBNames : teamANames;

  bool includesPlayer(String playerId) {
    final normalizedId = playerId.trim();
    return teamAPlayerIdList.contains(normalizedId) ||
        teamBPlayerIdList.contains(normalizedId);
  }

  String? sideForPlayer(String playerId) {
    final normalizedId = playerId.trim();
    if (teamAPlayerIdList.contains(normalizedId)) {
      return 'A';
    }
    if (teamBPlayerIdList.contains(normalizedId)) {
      return 'B';
    }
    return null;
  }

  bool didPlayerWin(String playerId) {
    final side = sideForPlayer(playerId);
    return side != null && side == winningSide;
  }

  List<String> partnerNamesFor(String playerId) {
    final side = sideForPlayer(playerId);
    if (side == null) {
      return const [];
    }

    final ids = side == 'A' ? teamAPlayerIdList : teamBPlayerIdList;
    final names = side == 'A' ? teamAPlayerNameList : teamBPlayerNameList;
    final normalizedId = playerId.trim();
    final partners = <String>[];

    for (var index = 0; index < names.length; index++) {
      final name = names[index];
      final id = index < ids.length ? ids[index] : null;
      if (id == normalizedId) {
        continue;
      }
      partners.add(name);
    }

    return partners;
  }

  List<String> opponentNamesFor(String playerId) {
    final side = sideForPlayer(playerId);
    if (side == 'A') {
      return teamBPlayerNameList;
    }
    if (side == 'B') {
      return teamAPlayerNameList;
    }
    return const [];
  }
}
