import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_club/auth_provider.dart';
import 'package:rally_club/models/app_user.dart';
import 'package:rally_club/models/match_record.dart';
import 'package:rally_club/models/player.dart';
import 'package:rally_club/player_match_history_screen.dart';

AppUser _buildUser() {
  return AppUser(
    uid: 'u1',
    email: 'user@example.com',
    playerId: 'p1',
    clubId: 'club-1',
    role: 'member',
    joinedAt: '2026-04-01T00:00:00Z',
  );
}

Player _buildPlayer() {
  return Player(
    id: 'p1',
    name: 'Jaycee',
    gender: 'Male',
    skillLevel: 'Intermediate',
    isAvailable: true,
    ownerUid: 'u1',
  );
}

Widget _buildWidget({
  required Player player,
  required Future<List<MatchRecord>> Function(String clubId) loadMatches,
}) {
  final auth = AuthProvider.test(
    appUser: _buildUser(),
    isLoading: false,
    isAuthenticated: true,
    isEmailVerified: true,
  );

  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: PlayerMatchHistoryScreen(player: player, loadMatches: loadMatches),
    ),
  );
}

void main() {
  testWidgets('shows player timeline summary with partners and opponents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final player = _buildPlayer();
    final matches = [
      MatchRecord(
        id: 'm1',
        gameMode: 'doubles',
        matchLogic: 'auto',
        teamAPlayerIds: 'p1,p2',
        teamBPlayerIds: 'p3,p4',
        teamANames: 'Jaycee, Jamie',
        teamBNames: 'Alex, Sam',
        winningSide: 'A',
        date: '2026-04-10T09:00:00.000',
      ),
      MatchRecord(
        id: 'm2',
        gameMode: 'singles',
        matchLogic: 'history',
        teamAPlayerIds: 'p1',
        teamBPlayerIds: 'p5',
        teamANames: 'Jaycee',
        teamBNames: 'Taylor',
        winningSide: 'B',
        date: '2026-04-09T09:00:00.000',
      ),
    ];

    await tester.pumpWidget(
      _buildWidget(player: player, loadMatches: (_) async => matches),
    );
    await tester.pumpAndSettle();

    expect(find.text('MY MATCH HISTORY'), findsOneWidget);
    expect(find.text('2 sessions played'), findsOneWidget);
    expect(find.text('RECENT RESULTS'), findsOneWidget);
    expect(find.text('Jamie'), findsOneWidget);
    expect(find.text('Alex, Sam'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('Taylor'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('LOSS'), findsOneWidget);
  });
}
