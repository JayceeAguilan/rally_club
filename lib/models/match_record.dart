class MatchRecord {
  final String? id;
  final String gameMode;       // 'singles' or 'doubles'
  final String matchLogic;     // 'auto', 'skill', 'history', 'mixed'
  final String teamAPlayerIds; // Comma-separated player IDs: "1,2"
  final String teamBPlayerIds; // Comma-separated player IDs: "3,4"
  final String teamANames;     // Comma-separated names: "Jaycee,James"
  final String teamBNames;     // Comma-separated names: "David,Elena"
  final String winningSide;    // 'A' or 'B'
  final String date;           // ISO 8601 datetime string
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

  /// Get the list of winning player IDs.
  List<String> get winnerPlayerIds {
    final ids = winningSide == 'A' ? teamAPlayerIds : teamBPlayerIds;
    return ids.split(',').map((e) => e.trim()).toList();
  }

  /// Get the list of losing player IDs.
  List<String> get loserPlayerIds {
    final ids = winningSide == 'A' ? teamBPlayerIds : teamAPlayerIds;
    return ids.split(',').map((e) => e.trim()).toList();
  }

  /// Human-readable winning team names.
  String get winnerNames => winningSide == 'A' ? teamANames : teamBNames;

  /// Human-readable losing team names.
  String get loserNames => winningSide == 'A' ? teamBNames : teamANames;
}
