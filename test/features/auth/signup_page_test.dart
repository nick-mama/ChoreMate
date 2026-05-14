import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:choremate/features/auth/pages/signup_page.dart';
import 'package:choremate/core/services/auth_repository.dart';

class FakeAuthService implements AuthRepository {
  String? email;
  String? password;
  String? firstName;
  String? lastName;
  String? username;
  String? phone;
  FirebaseAuthException? signupException;
  bool verificationEmailSent = false;

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    String? phone,
  }) async {
    this.email = email;
    this.password = password;
    this.firstName = firstName;
    this.lastName = lastName;
    this.username = username;
    this.phone = phone;

    if (signupException != null) {
      throw signupException!;
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    verificationEmailSent = true;
  }

  @override
  Future<bool> checkEmailVerified() async {
    return false;
  }

  @override
  Future<UserCredential> login(String email, String password) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('shows error when passwords do not match', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(MaterialApp(home: SignupPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      'password2',
    );
    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.email, isNull);
  });

  testWidgets('shows error when password is shorter than 6 characters', (
    tester,
  ) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(MaterialApp(home: SignupPage(auth: auth)));

    await tester.enterText(find.widgetWithText(TextField, 'Password'), '12345');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      '12345',
    );
    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    expect(auth.email, isNull);
  });

  testWidgets('trims text inputs but not password', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: SignupPage(auth: auth),
        routes: {'/verify': (_) => const Scaffold(body: Text('Verify'))},
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'First Name'),
      ' Alex ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Last Name'),
      ' Kim ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Username'),
      ' alexk ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      ' alex@email.com ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone Number (optional)'),
      ' 5551234567 ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      ' password ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      ' password ',
    );

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(auth.firstName, 'Alex');
    expect(auth.lastName, 'Kim');
    expect(auth.username, 'alexk');
    expect(auth.email, 'alex@email.com');
    expect(auth.phone, '5551234567');
    expect(auth.password, ' password ');
  });

  testWidgets('sends verification email after signup', (tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: SignupPage(auth: auth),
        routes: {'/verify': (_) => const Scaffold(body: Text('Verify'))},
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'First Name'),
      'Alex',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Last Name'), 'Kim');
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alexk');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'alex@email.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      'password',
    );

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(auth.verificationEmailSent, isTrue);
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('shows friendly error when email already exists', (tester) async {
    final auth = FakeAuthService()
      ..signupException = FirebaseAuthException(code: 'email-already-in-use');

    await tester.pumpWidget(MaterialApp(home: SignupPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'test@email.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      'password',
    );

    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(
      find.text('An account with that email already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('shows friendly error for invalid email', (tester) async {
    final auth = FakeAuthService()
      ..signupException = FirebaseAuthException(code: 'invalid-email');

    await tester.pumpWidget(MaterialApp(home: SignupPage(auth: auth)));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'bad-email',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'password',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm Password'),
      'password',
    );

    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });
}
