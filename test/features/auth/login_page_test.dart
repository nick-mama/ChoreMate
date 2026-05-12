import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:choremate/features/auth/pages/login_page.dart';
import 'package:choremate/core/services/auth_repository.dart';

class MockUserCredential extends Mock implements UserCredential {}

class FakeAuthService implements AuthRepository {
  String? email;
  String? password;
  String? resetEmail;
  FirebaseAuthException? loginException;

  @override
  Future<UserCredential> login(String email, String password) async {
    this.email = email;
    this.password = password;

    if (loginException != null) {
      throw loginException!;
    }

    return MockUserCredential();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    String? phone,
  }) async {}

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('trims email but not password when logging in', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(auth: auth),
        routes: {'/splash': (_) => const Scaffold(body: Text('Splash'))},
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      ' test@email.com ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      ' password ',
    );

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(auth.email, 'test@email.com');
    expect(auth.password, ' password ');
  });

  testWidgets('shows friendly error for invalid credentials', (tester) async {
    final auth = FakeAuthService()
      ..loginException = FirebaseAuthException(code: 'invalid-credential');

    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'test@email.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('shows friendly error for too many attempts', (tester) async {
    final auth = FakeAuthService()
      ..loginException = FirebaseAuthException(code: 'too-many-requests');

    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'test@email.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Too many attempts. Try again later.'), findsOneWidget);
  });

  testWidgets('sends password reset email with trimmed email', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    final resetEmailField = find.widgetWithText(TextField, 'Email').last;

    await tester.enterText(resetEmailField, ' reset@email.com ');

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(auth.resetEmail, 'reset@email.com');
    expect(find.text('Password reset email sent.'), findsOneWidget);
  });
}
