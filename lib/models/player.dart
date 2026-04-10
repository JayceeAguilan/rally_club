/// Represents a player in the Rally Club system.
/// Standings (wins, losses, winRate, matchesPlayed) are computed dynamically
/// from match history. Only `lastResult` is stored directly for the
/// Winners & Losers matching algorithm.
class Player {
  static const String guestIdPrefix = 'guest:';

  final String? id;
  final String name;
  final String gender; // 'Male' or 'Female'
  final String skillLevel; // 'Beg', 'Int', 'Adv'
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
    required this.skillLevel,
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

  static String normalizeSkillLevelCode(String skillLevel) {
    switch (skillLevel.trim().toLowerCase()) {
      case 'beginner':
      case 'beg':
        return 'Beg';
      case 'intermediate':
      case 'int':
        return 'Int';
      case 'advanced':
      case 'adv':
        return 'Adv';
      case 'pro':
        return 'Adv';
      default:
        return skillLevel.trim();
    }
  }

  static String displaySkillLevel(String skillLevel) {
    switch (normalizeSkillLevelCode(skillLevel)) {
      case 'Beg':
        return 'Beginner';
      case 'Int':
        return 'Intermediate';
      case 'Adv':
        return 'Advanced';
      default:
        return skillLevel.trim();
    }
  }

  String get normalizedSkillLevel => normalizeSkillLevelCode(skillLevel);

  String get displaySkillLabel => displaySkillLevel(skillLevel);

  bool matchesSkillFilter(String filterSkill) {
    return filterSkill == 'All' ||
        normalizedSkillLevel == normalizeSkillLevelCode(filterSkill);
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'skillLevel': normalizedSkillLevel,
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
      skillLevel: normalizeSkillLevelCode(map['skillLevel'] ?? ''),
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
      'skillLevel': normalizedSkillLevel,
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
