import 'package:flutter_test/flutter_test.dart';
import 'package:rally_club/announcement_notification_utils.dart';

void main() {
  test('announcementTopicForClub normalizes unsupported characters', () {
    expect(
      announcementTopicForClub('Rally Club / Alpha'),
      'club_rally_club___alpha_announcements',
    );
  });

  test('isAnnouncementNotificationData only matches announcement type', () {
    expect(isAnnouncementNotificationData({'type': 'announcement'}), isTrue);
    expect(isAnnouncementNotificationData({'type': 'match'}), isFalse);
    expect(isAnnouncementNotificationData({}), isFalse);
  });
}
