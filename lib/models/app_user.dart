/// Represents a signed-in user's profile stored at users/{uid}.
/// Links the Firebase Auth account to a player record and club membership.
class AppUser {
  final String uid;
  final String email;
  final String? playerId;
  final String? clubId;
  final String role; // 'member' or 'admin'
  final String joinedAt;
  final String? announcementLastSeenAt;

  AppUser({
    required this.uid,
    required this.email,
    this.playerId,
    this.clubId,
    this.role = 'member',
    required this.joinedAt,
    this.announcementLastSeenAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'playerId': playerId,
      'clubId': clubId,
      'role': role,
      'joinedAt': joinedAt,
      'announcementLastSeenAt': announcementLastSeenAt,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'],
      email: map['email'] ?? '',
      playerId: map['playerId'],
      clubId: map['clubId'],
      role: map['role'] ?? 'member',
      joinedAt: map['joinedAt'] ?? '',
      announcementLastSeenAt: map['announcementLastSeenAt'],
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? playerId,
    String? clubId,
    String? role,
    String? joinedAt,
    String? announcementLastSeenAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      playerId: playerId ?? this.playerId,
      clubId: clubId ?? this.clubId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      announcementLastSeenAt:
          announcementLastSeenAt ?? this.announcementLastSeenAt,
    );
  }
}
