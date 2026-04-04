import 'announcement.dart';

class AnnouncementInboxStatus {
  final int unreadCount;
  final Announcement? latestUnreadAnnouncement;

  const AnnouncementInboxStatus({
    this.unreadCount = 0,
    this.latestUnreadAnnouncement,
  });
}
