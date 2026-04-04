import 'package:flutter_test/flutter_test.dart';

import 'package:rally_club/models/announcement.dart';
import 'package:rally_club/models/announcement_comment.dart';

void main() {
  test('Announcement round-trips through toMap/fromMap', () {
    final announcement = Announcement(
      id: 'a1',
      title: 'Saturday Club Play',
      scheduledAt: '2026-04-05T09:30:00.000',
      location: 'Central Court',
      createdByUid: 'admin-1',
      createdByName: 'Coach Jay',
      clubId: 'club-1',
      createdAt: '2026-04-04T10:00:00.000',
      updatedAt: '2026-04-04T10:00:00.000',
    );

    final map = announcement.toMap();
    final restored = Announcement.fromMap(map);

    expect(restored.id, 'a1');
    expect(restored.title, 'Saturday Club Play');
    expect(restored.location, 'Central Court');
    expect(restored.createdByName, 'Coach Jay');
    expect(
      restored.scheduledDateTime,
      DateTime.parse('2026-04-05T09:30:00.000'),
    );
  });

  test('AnnouncementComment round-trips through toMap/fromMap', () {
    final comment = AnnouncementComment(
      id: 'c1',
      announcementId: 'a1',
      clubId: 'club-1',
      authorUid: 'member-1',
      authorName: 'Taylor',
      text: 'I can make it.',
      createdAt: '2026-04-04T11:00:00.000',
      updatedAt: '2026-04-04T11:05:00.000',
    );

    final map = comment.toMap();
    final restored = AnnouncementComment.fromMap(map);

    expect(restored.id, 'c1');
    expect(restored.announcementId, 'a1');
    expect(restored.authorName, 'Taylor');
    expect(restored.text, 'I can make it.');
    expect(restored.createdDateTime, DateTime.parse('2026-04-04T11:00:00.000'));
  });
}
