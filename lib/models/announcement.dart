class Announcement {
  final String? id;
  final String title;
  final String scheduledAt;
  final String location;
  final String createdByUid;
  final String createdByName;
  final String? clubId;
  final String createdAt;
  final String updatedAt;

  Announcement({
    this.id,
    required this.title,
    required this.scheduledAt,
    required this.location,
    required this.createdByUid,
    required this.createdByName,
    this.clubId,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get scheduledDateTime => DateTime.tryParse(scheduledAt);
  DateTime? get createdDateTime => DateTime.tryParse(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'scheduledAt': scheduledAt,
      'location': location,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'clubId': clubId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'],
      title: map['title'] ?? '',
      scheduledAt: map['scheduledAt'] ?? '',
      location: map['location'] ?? '',
      createdByUid: map['createdByUid'] ?? '',
      createdByName: map['createdByName'] ?? '',
      clubId: map['clubId'],
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
    );
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? scheduledAt,
    String? location,
    String? createdByUid,
    String? createdByName,
    String? clubId,
    String? createdAt,
    String? updatedAt,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      location: location ?? this.location,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      clubId: clubId ?? this.clubId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
