import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_club/auth_gate.dart';
import 'package:rally_club/auth_provider.dart';
import 'package:rally_club/login_screen.dart';
import 'package:rally_club/splash_screen.dart';

class _FailingAuthProvider extends AuthProvider {
  _FailingAuthProvider(this.exception) : super.test(isLoading: false);

  final FirebaseAuthException exception;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    throw exception;
  }
}

class _CapturingAuthProvider extends AuthProvider {
  _CapturingAuthProvider({super.rememberMe = true})
    : super.test(isLoading: false);

  bool? lastRememberMe;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    lastEmail = email;
    lastPassword = password;
    lastRememberMe = rememberMe;
    throw Exception('captured sign in');
  }
}

Widget _buildTestWidget(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: const MaterialApp(home: LoginScreen()),
  );
}

Widget _buildGoogleUiTestWidget(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: const MaterialApp(home: LoginScreen(showGoogleSignIn: true)),
  );
}

Widget _buildAuthGateTestWidget(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: const MaterialApp(home: AuthGate()),
  );
}

void main() {
  testWidgets('shows incorrect credential feedback and clears it on input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FailingAuthProvider(
      FirebaseAuthException(code: 'invalid-credential'),
    );

    await tester.pumpWidget(_buildTestWidget(auth));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'bad-password');

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(
      find.text('Incorrect email or password. Please try again.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(1), 'bad-password-2');
    await tester.pump();

    expect(
      find.text('Incorrect email or password. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('failed sign in stays on login instead of flashing splash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FailingAuthProvider(
      FirebaseAuthException(code: 'invalid-credential'),
    );

    await tester.pumpWidget(_buildAuthGateTestWidget(auth));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'bad-password');

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(
      find.text('Incorrect email or password. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('remember me checkbox reflects saved preference', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _CapturingAuthProvider(rememberMe: false);

    await tester.pumpWidget(_buildTestWidget(auth));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(find.text('Remember me'), findsOneWidget);
  });

  testWidgets('sign in forwards remember me preference', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _CapturingAuthProvider();

    await tester.pumpWidget(_buildTestWidget(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secure-password');

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, 'member@example.com');
    expect(auth.lastPassword, 'secure-password');
    expect(auth.lastRememberMe, isFalse);
  });

  testWidgets('web google sign-in button is shown as UI-only placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _CapturingAuthProvider();

    await tester.pumpWidget(_buildGoogleUiTestWidget(auth));
    await tester.pumpAndSettle();

    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);

    await tester.tap(find.text('CONTINUE WITH GOOGLE'));
    await tester.pumpAndSettle();

    expect(find.text('Google sign-in for web is coming soon.'), findsOneWidget);
  });
}
