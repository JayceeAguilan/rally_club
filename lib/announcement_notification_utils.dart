const int announcementsTabIndex = 4;

String announcementTopicForClub(String clubId) {
  final cleaned = clubId.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9\-_.~%]'),
    '_',
  );
  final normalized = cleaned.isEmpty ? 'default' : cleaned;
  return 'club_${normalized}_announcements';
}

bool isAnnouncementNotificationData(Map<String, dynamic> data) {
  return data['type']?.toString() == 'announcement';
}
