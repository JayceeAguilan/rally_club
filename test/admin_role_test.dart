import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_club/auth_provider.dart';
import 'package:rally_club/match_generator.dart';
import 'package:rally_club/match_result_screen.dart';
import 'package:rally_club/match_setup_screen.dart';
import 'package:rally_club/models/app_user.dart';
import 'package:rally_club/models/player.dart';

AppUser _buildUser({required String role}) {
  return AppUser(
    uid: 'u1',
    email: 'user@example.com',
    playerId: 'p1',
    clubId: 'club-1',
    role: role,
    joinedAt: '2026-01-01T00:00:00Z',
  );
}

GeneratedMatch _buildGeneratedMatch() {
  return GeneratedMatch(
    teamA: [
      Player(
        id: 'p1',
        name: 'Alice',
        gender: 'Female',
        skillLevel: 'Int',
        isAvailable: true,
      ),
    ],
    teamB: [
      Player(
        id: 'p2',
        name: 'Bob',
        gender: 'Male',
        skillLevel: 'Int',
        isAvailable: true,
      ),
    ],
    gameMode: 'singles',
    matchLogic: 'auto',
  );
}

Widget _wrapWithAuth({required AuthProvider auth, required Widget child}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(home: child),
  );
}

void main() {
  group('AuthProvider admin role', () {
    test('isAdmin is true for admin users', () {
      final auth = AuthProvider.test(
        appUser: _buildUser(role: 'admin'),
        isLoading: false,
      );

      expect(auth.isAdmin, isTrue);
    });

    test('isAdmin is false for member users', () {
      final auth = AuthProvider.test(
        appUser: _buildUser(role: 'member'),
        isLoading: false,
      );

      expect(auth.isAdmin, isFalse);
    });
  });

  group('Admin-only match flows', () {
    testWidgets('member sees access denied on match setup', (tester) async {
      final auth = AuthProvider.test(
        appUser: _buildUser(role: 'member'),
        isLoading: false,
      );

      await tester.pumpWidget(
        _wrapWithAuth(auth: auth, child: const MatchSetupScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Access Required'), findsOneWidget);
      expect(
        find.text('Only admin accounts can generate matches.'),
        findsOneWidget,
      );
    });

    testWidgets('member sees access denied on match result screen', (
      tester,
    ) async {
      final auth = AuthProvider.test(
        appUser: _buildUser(role: 'member'),
        isLoading: false,
      );

      await tester.pumpWidget(
        _wrapWithAuth(
          auth: auth,
          child: MatchResultScreen(match: _buildGeneratedMatch()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Access Required'), findsOneWidget);
      expect(
        find.text('Only admin accounts can declare and save match results.'),
        findsOneWidget,
      );
      expect(find.text('Save Result'), findsNothing);
    });

    testWidgets('admin can access match result screen actions', (tester) async {
      final auth = AuthProvider.test(
        appUser: _buildUser(role: 'admin'),
        isLoading: false,
      );

      await tester.pumpWidget(
        _wrapWithAuth(
          auth: auth,
          child: MatchResultScreen(match: _buildGeneratedMatch()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Access Required'), findsNothing);
      expect(find.text('Save Result'), findsOneWidget);
    });
  });
}
