// Smoke test for the auth-gated Rally Club app.
//
// Uses AuthProvider.test() to supply controlled auth state without
// requiring a live Firebase backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_club/auth_provider.dart';
import 'package:rally_club/main.dart';

void main() {
  testWidgets('Unauthenticated user sees login screen', (
    WidgetTester tester,
  ) async {
    // Use a phone-sized viewport to avoid layout overflow in LoginScreen
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockAuth = AuthProvider.test(isLoading: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuth,
        child: const KineticCourtApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Login screen should display the sign-in form
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Welcome back to Rally Club'), findsOneWidget);
  });

  testWidgets('Loading state shows splash screen', (WidgetTester tester) async {
    final mockAuth = AuthProvider.test(isLoading: true);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuth,
        child: const KineticCourtApp(),
      ),
    );
    await tester.pump();

    // While loading, the splash/loading screen should be visible, not the login form
    expect(find.text('Sign In'), findsNothing);
  });
}
