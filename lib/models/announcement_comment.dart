class AnnouncementComment {
  final String? id;
  final String announcementId;
  final String? clubId;
  final String authorUid;
  final String authorName;
  final String text;
  final String createdAt;
  final String updatedAt;

  AnnouncementComment({
    this.id,
    required this.announcementId,
    this.clubId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get createdDateTime => DateTime.tryParse(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'announcementId': announcementId,
      'clubId': clubId,
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory AnnouncementComment.fromMap(Map<String, dynamic> map) {
    return AnnouncementComment(
      id: map['id'],
      announcementId: map['announcementId'] ?? '',
      clubId: map['clubId'],
      authorUid: map['authorUid'] ?? '',
      authorName: map['authorName'] ?? '',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
    );
  }

  AnnouncementComment copyWith({
    String? id,
    String? announcementId,
    String? clubId,
    String? authorUid,
    String? authorName,
    String? text,
    String? createdAt,
    String? updatedAt,
  }) {
    return AnnouncementComment(
      id: id ?? this.id,
      announcementId: announcementId ?? this.announcementId,
      clubId: clubId ?? this.clubId,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
