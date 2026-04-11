import '../dupr_rating.dart';

/// Represents a player in the Rally Club system.
/// Standings (wins, losses, winRate, matchesPlayed) are computed dynamically
/// from match history. Only `lastResult` is stored directly for the
/// Winners & Losers matching algorithm.
class Player {
  static const String guestIdPrefix = 'guest:';

  final String? id;
  final String name;
  final String gender; // 'Male' or 'Female'
  final String skillLevel; // Legacy-only manual field kept for migration reads.
  final double duprRating;
  final int duprMatchesPlayed;
  final String? duprLastUpdatedAt;
  final bool countsAsPlayer;
  final bool isAvailable;
  final String notes;
  final String lastResult; // 'win', 'loss', or 'none'
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final String? profileImageBase64;
  final String? clubId;
  final String? ownerUid;
  final bool isLegacy;
  final bool isGuest;

  Player({
    this.id,
    required this.name,
    required this.gender,
    this.skillLevel = '',
    this.duprRating = DuprRating.baselineRating,
    this.duprMatchesPlayed = 0,
    this.duprLastUpdatedAt,
    this.countsAsPlayer = true,
    required this.isAvailable,
    this.notes = '',
    this.lastResult = 'none',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.profileImageBase64,
    this.clubId,
    this.ownerUid,
    this.isLegacy = false,
    this.isGuest = false,
  });

  static bool isGuestId(String? playerId) {
    return playerId?.trim().startsWith(guestIdPrefix) ?? false;
  }

  bool get isRated => DuprRating.isRated(duprMatchesPlayed);

  double get effectiveDuprRating => DuprRating.normalizeRating(duprRating);

  String get displayDuprRating => DuprRating.formatRating(effectiveDuprRating);

  String get displayDuprLabel => isRated
      ? 'DUPR $displayDuprRating'
      : 'DUPR $displayDuprRating BASELINE';

  static String displaySkillLevelFromRating({
    required double rating,
    required int ratedMatches,
  }) {
    return DuprRating.labelForRating(
      rating: rating,
      ratedMatches: ratedMatches,
    );
  }

  String get displaySkillLabel => displaySkillLevelFromRating(
    rating: effectiveDuprRating,
    ratedMatches: duprMatchesPlayed,
  );

  bool matchesSkillFilter(String filterSkill) {
    return DuprRating.matchesFilter(
      filter: filterSkill,
      currentLabel: displaySkillLabel,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'duprRating': effectiveDuprRating,
      'duprMatchesPlayed': duprMatchesPlayed,
      'duprLastUpdatedAt': duprLastUpdatedAt ?? now,
      'countsAsPlayer': countsAsPlayer ? 1 : 0,
      'isAvailable': isAvailable ? 1 : 0,
      'notes': notes,
      'lastResult': lastResult,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt ?? now,
      'updatedAt': now,
      'profileImageBase64': profileImageBase64,
      'clubId': clubId,
      'ownerUid': ownerUid,
      'isLegacy': isLegacy ? 1 : 0,
      'isGuest': isGuest ? 1 : 0,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      name: map['name'],
      gender: map['gender'],
      skillLevel: (map['skillLevel'] ?? '').toString(),
      duprRating: DuprRating.normalizeRating(map['duprRating']),
      duprMatchesPlayed: (map['duprMatchesPlayed'] as num?)?.toInt() ?? 0,
      duprLastUpdatedAt: map['duprLastUpdatedAt'] as String?,
      countsAsPlayer: (map['countsAsPlayer'] ?? 1) == 1,
      isAvailable: map['isAvailable'] == 1,
      notes: map['notes'] ?? '',
      lastResult: map['lastResult'] ?? 'none',
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      profileImageBase64: map['profileImageBase64'],
      clubId: map['clubId'],
      ownerUid: map['ownerUid'],
      isLegacy: (map['isLegacy'] ?? 0) == 1,
      isGuest: (map['isGuest'] ?? 0) == 1 || isGuestId(map['id'] as String?),
    );
  }

  Map<String, dynamic> toProfileUpdateMap() {
    return {
      'name': name,
      'gender': gender,
      'isAvailable': isAvailable ? 1 : 0,
      'notes': notes,
      'profileImageBase64': profileImageBase64,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  bool isOwnedByUser({String? linkedPlayerId, String? userUid}) {
    if (linkedPlayerId != null &&
        linkedPlayerId.isNotEmpty &&
        id == linkedPlayerId) {
      return true;
    }

    return userUid != null && userUid.isNotEmpty && ownerUid == userUid;
  }

  /// Create a copy with updated fields.
  Player copyWith({
    String? id,
    String? name,
    String? gender,
    String? skillLevel,
    double? duprRating,
    int? duprMatchesPlayed,
    String? duprLastUpdatedAt,
    bool? countsAsPlayer,
    bool? isAvailable,
    String? notes,
    String? lastResult,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? profileImageBase64,
    String? clubId,
    String? ownerUid,
    bool? isLegacy,
    bool? isGuest,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      skillLevel: skillLevel ?? this.skillLevel,
      duprRating: duprRating ?? this.duprRating,
      duprMatchesPlayed: duprMatchesPlayed ?? this.duprMatchesPlayed,
      duprLastUpdatedAt: duprLastUpdatedAt ?? this.duprLastUpdatedAt,
      countsAsPlayer: countsAsPlayer ?? this.countsAsPlayer,
      isAvailable: isAvailable ?? this.isAvailable,
      notes: notes ?? this.notes,
      lastResult: lastResult ?? this.lastResult,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      clubId: clubId ?? this.clubId,
      ownerUid: ownerUid ?? this.ownerUid,
      isLegacy: isLegacy ?? this.isLegacy,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
