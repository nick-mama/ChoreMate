import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:choremate/features/auth/pages/login_page.dart';
import 'package:choremate/core/services/auth_repository.dart';
import 'package:choremate/app/router.dart';

class MockUserCredential extends Mock implements UserCredential {}

class FakeAuthService implements AuthRepository {
  String? email;
  String? password;
  String? resetEmail;
  FirebaseAuthException? loginException;
  bool emailVerified = true;
  bool verificationEmailSent = false;

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
  Future<bool> checkEmailVerified() async {
    return emailVerified;
  }

  @override
  Future<void> sendVerificationEmail() async {
    verificationEmailSent = true;
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
  testWidgets('trims login input but not password', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(auth: auth),
        routes: {AppRouter.splash: (_) => const Scaffold(body: Text('Splash'))},
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or Email'),
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

  testWidgets('passes username login input through auth service', (
    tester,
  ) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(auth: auth),
        routes: {'/splash': (_) => const Scaffold(body: Text('Splash'))},
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or Email'),
      ' cleanqueen ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(auth.email, 'cleanqueen');
    expect(auth.password, 'password');
  });

  testWidgets('goes to splash when email is verified', (tester) async {
    final auth = FakeAuthService()..emailVerified = true;

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/login',
        routes: {
          '/login': (_) => LoginPage(auth: auth),
          AppRouter.splash: (_) => const Scaffold(body: Text('Splash')),
        },
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or Email'),
      'test@email.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(auth.email, 'test@email.com');
    expect(find.text('Splash'), findsOneWidget);
    expect(auth.verificationEmailSent, isFalse);
  });

  testWidgets(
    'goes to verify page and sends email when email is not verified',
    (tester) async {
      final auth = FakeAuthService()..emailVerified = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(auth: auth),
          routes: {
            AppRouter.verify: (_) => const Scaffold(body: Text('Verify Email')),
          },
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Username or Email'),
        'test@email.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password',
      );

      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Email'), findsOneWidget);
      expect(auth.verificationEmailSent, isTrue);
    },
  );

  testWidgets('shows friendly error when account is not found', (tester) async {
    final auth = FakeAuthService()
      ..loginException = FirebaseAuthException(code: 'account-not-found');

    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or Email'),
      'missing_user',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(
      find.text('There is no account for that username/email.'),
      findsOneWidget,
    );
  });

  testWidgets('shows friendly error for invalid credentials', (tester) async {
    final auth = FakeAuthService()
      ..loginException = FirebaseAuthException(code: 'invalid-credential');

    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or Email'),
      'test@email.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Incorrect password.'), findsOneWidget);
  });

  testWidgets('shows friendly error for too many attempts', (tester) async {
    final auth = FakeAuthService()
      ..loginException = FirebaseAuthException(code: 'too-many-requests');

    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or Email'),
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
