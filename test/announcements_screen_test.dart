import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_club/announcements_screen.dart';
import 'package:rally_club/auth_provider.dart';
import 'package:rally_club/models/announcement.dart';
import 'package:rally_club/models/announcement_inbox_status.dart';
import 'package:rally_club/models/app_user.dart';

AppUser _buildUser({required String role}) {
  return AppUser(
    uid: 'u1',
    email: 'user@example.com',
    playerId: 'p1',
    clubId: 'club-1',
    role: role,
    joinedAt: '2026-04-01T00:00:00Z',
  );
}

Announcement _buildAnnouncement() {
  return Announcement(
    id: 'a1',
    title: 'Sunday Morning Open Play',
    scheduledAt: '2026-04-05T09:30:00.000',
    location: 'North Court',
    createdByUid: 'admin-1',
    createdByName: 'Coach Jay',
    clubId: 'club-1',
    createdAt: '2026-04-04T08:00:00.000',
    updatedAt: '2026-04-04T08:00:00.000',
  );
}

Announcement _buildAnnouncementWith({
  required String id,
  required String title,
  required String createdAt,
  String scheduledAt = '2026-04-05T09:30:00.000',
}) {
  return Announcement(
    id: id,
    title: title,
    scheduledAt: scheduledAt,
    location: 'North Court',
    createdByUid: 'admin-1',
    createdByName: 'Coach Jay',
    clubId: 'club-1',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Widget _buildWidget({
  required AuthProvider auth,
  required Future<List<Announcement>> Function(String clubId) loader,
  Future<AnnouncementInboxStatus> Function(String uid, String clubId)?
  inboxLoader,
  Future<void> Function(String uid, String clubId)? markSeen,
  Future<DateTime?> Function(BuildContext context, DateTime initialDate)?
  pickFilterDate,
}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: AnnouncementsScreen(
        loadAnnouncements: loader,
        loadInboxStatus: inboxLoader,
        markAnnouncementsSeen: markSeen,
        pickFilterDate: pickFilterDate,
      ),
    ),
  );
}

void main() {
  testWidgets('admin sees announcements and can post a new one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider.test(
      appUser: _buildUser(role: 'admin'),
      isLoading: false,
      isAuthenticated: true,
      isEmailVerified: true,
    );

    await tester.pumpWidget(
      _buildWidget(auth: auth, loader: (_) async => [_buildAnnouncement()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLUB UPDATES'), findsOneWidget);
    expect(find.text('Sunday Morning Open Play'), findsOneWidget);
    expect(find.text('Post Announcement'), findsOneWidget);
  });

  testWidgets('member sees unread summary banner when announcements are new', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider.test(
      appUser: _buildUser(role: 'member'),
      isLoading: false,
      isAuthenticated: true,
      isEmailVerified: true,
    );

    var markSeenCallCount = 0;

    await tester.pumpWidget(
      _buildWidget(
        auth: auth,
        loader: (_) async => [_buildAnnouncement()],
        inboxLoader: (_, _) async => AnnouncementInboxStatus(
          unreadCount: 1,
          latestUnreadAnnouncement: _buildAnnouncement(),
        ),
        markSeen: (_, _) async {
          markSeenCallCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('1 new announcement since your last visit.'),
      findsOneWidget,
    );
    expect(find.text('Sunday Morning Open Play'), findsNWidgets(2));
    expect(markSeenCallCount, 1);
  });

  testWidgets('member can view announcements but not post them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider.test(
      appUser: _buildUser(role: 'member'),
      isLoading: false,
      isAuthenticated: true,
      isEmailVerified: true,
    );

    await tester.pumpWidget(
      _buildWidget(auth: auth, loader: (_) async => [_buildAnnouncement()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sunday Morning Open Play'), findsOneWidget);
    expect(find.text('Post Announcement'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();

    expect(
      find.text('No announcements match that search or date yet.'),
      findsOneWidget,
    );
  });

  testWidgets('newer announcements render before older ones', (tester) async {
    tester.view.physicalSize = const Size(1280, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider.test(
      appUser: _buildUser(role: 'member'),
      isLoading: false,
      isAuthenticated: true,
      isEmailVerified: true,
    );

    final olderAnnouncement = _buildAnnouncementWith(
      id: 'a-old',
      title: 'Older Club Update',
      createdAt: '2026-04-03T08:00:00.000',
    );
    final newerAnnouncement = _buildAnnouncementWith(
      id: 'a-new',
      title: 'Newest Club Update',
      createdAt: '2026-04-05T08:00:00.000',
    );

    await tester.pumpWidget(
      _buildWidget(
        auth: auth,
        loader: (_) async => [olderAnnouncement, newerAnnouncement],
      ),
    );
    await tester.pumpAndSettle();

    final titleTexts = tester.widgetList<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'Older Club Update' ||
                widget.data == 'Newest Club Update'),
      ),
    );

    expect(titleTexts.map((text) => text.data).toList(), [
      'Newest Club Update',
      'Older Club Update',
    ]);
  });

  testWidgets('date filter narrows announcements by scheduled day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider.test(
      appUser: _buildUser(role: 'member'),
      isLoading: false,
      isAuthenticated: true,
      isEmailVerified: true,
    );

    final tuesdayAnnouncement = _buildAnnouncementWith(
      id: 'a-tue',
      title: 'Tuesday Open Play',
      createdAt: '2026-04-03T08:00:00.000',
      scheduledAt: '2026-04-07T09:30:00.000',
    );
    final thursdayAnnouncement = _buildAnnouncementWith(
      id: 'a-thu',
      title: 'Thursday Drill Session',
      createdAt: '2026-04-04T08:00:00.000',
      scheduledAt: '2026-04-09T18:00:00.000',
    );

    await tester.pumpWidget(
      _buildWidget(
        auth: auth,
        loader: (_) async => [tuesdayAnnouncement, thursdayAnnouncement],
        pickFilterDate: (context, initialDate) async => DateTime(2026, 4, 9),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tuesday Open Play'), findsOneWidget);
    expect(find.text('Thursday Drill Session'), findsOneWidget);

    await tester.tap(find.text('Filter by date'));
    await tester.pumpAndSettle();

    expect(find.text('Apr 9, 2026'), findsOneWidget);
    expect(find.text('Thursday Drill Session'), findsOneWidget);
    expect(find.text('Tuesday Open Play'), findsNothing);

    await tester.tap(find.text('Clear date'));
    await tester.pumpAndSettle();

    expect(find.text('Filter by date'), findsOneWidget);
    expect(find.text('Tuesday Open Play'), findsOneWidget);
    expect(find.text('Thursday Drill Session'), findsOneWidget);
  });
}
