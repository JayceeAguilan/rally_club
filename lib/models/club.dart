/// Represents a club stored at clubs/{clubId}.
/// In v1 there is a single shared club; this model supports future expansion.
class Club {
  final String id;
  final String name;
  final String createdAt;

  /// The well-known document ID used for the single default Rally Club.
  static const String defaultClubId = 'rally_club_default';

  Club({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
    };
  }

  factory Club.fromMap(Map<String, dynamic> map) {
    return Club(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }
}
