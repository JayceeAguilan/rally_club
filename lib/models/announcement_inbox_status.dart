import 'announcement.dart';

class AnnouncementInboxStatus {
  final int unreadCount;
  final Announcement? latestUnreadAnnouncement;

  const AnnouncementInboxStatus({
    this.unreadCount = 0,
    this.latestUnreadAnnouncement,
  });

  Map<String, dynamic> toMap() {
    return {
      'unreadCount': unreadCount,
      'latestUnreadAnnouncement': latestUnreadAnnouncement?.toMap(),
    };
  }

  factory AnnouncementInboxStatus.fromMap(Map<String, dynamic> map) {
    final latestUnreadAnnouncement = map['latestUnreadAnnouncement'];
    return AnnouncementInboxStatus(
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      latestUnreadAnnouncement: latestUnreadAnnouncement is Map<String, dynamic>
          ? Announcement.fromMap(latestUnreadAnnouncement)
          : latestUnreadAnnouncement is Map
          ? Announcement.fromMap(
              Map<String, dynamic>.from(latestUnreadAnnouncement),
            )
          : null,
    );
  }
}
