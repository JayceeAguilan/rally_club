import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_club/auth_gate.dart';
import 'package:rally_club/auth_provider.dart';
import 'package:rally_club/login_screen.dart';
import 'package:rally_club/models/app_user.dart';
import 'package:rally_club/splash_screen.dart';
import 'package:rally_club/verify_email_screen.dart';

/// Wraps AuthGate with a MaterialApp and the given AuthProvider.
Widget _buildTestWidget(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: const MaterialApp(home: AuthGate()),
  );
}

void main() {
  group('AuthGate routing', () {
    testWidgets('shows SplashScreen while loading', (tester) async {
      final auth = AuthProvider.test(isLoading: true);

      await tester.pumpWidget(_buildTestWidget(auth));
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('shows LoginScreen when unauthenticated', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = AuthProvider.test(isLoading: false);

      await tester.pumpWidget(_buildTestWidget(auth));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets(
      'shows VerifyEmailScreen when signed in but email is unverified',
      (tester) async {
        final auth = AuthProvider.test(
          appUser: AppUser(
            uid: 'u1',
            email: 'member@example.com',
            playerId: 'p1',
            clubId: 'club-1',
            joinedAt: '2026-01-01T00:00:00Z',
          ),
          isLoading: false,
          isAuthenticated: true,
          isEmailVerified: false,
        );

        await tester.pumpWidget(_buildTestWidget(auth));
        await tester.pumpAndSettle();

        expect(find.byType(VerifyEmailScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(SplashScreen), findsNothing);
      },
    );
  });
}
