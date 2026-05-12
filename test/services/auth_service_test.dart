import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:choremate/core/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore db;
  late AuthService service;

  setUp(() {
    auth = MockFirebaseAuth();
    db = FakeFirebaseFirestore();
    service = AuthService(auth: auth, db: db);
  });

  group('AuthService', () {
    test('login signs in with email and password', () async {
      final credential = MockUserCredential();

      when(
        () => auth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async => credential);

      when(() => auth.currentUser).thenReturn(null);

      final result = await service.login('test@example.com', 'password123');

      expect(result, credential);

      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);
    });

    test(
      'signup creates user, stores profile, and sends verification',
      () async {
        final credential = MockUserCredential();
        final user = MockUser();

        when(() => credential.user).thenReturn(user);
        when(() => user.uid).thenReturn('user-1');
        when(
          () => user.updateDisplayName('cleanqueen'),
        ).thenAnswer((_) async {});
        when(() => user.sendEmailVerification()).thenAnswer((_) async {});

        when(
          () => auth.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).thenAnswer((_) async => credential);

        await service.signup(
          email: 'test@example.com',
          password: 'password123',
          firstName: 'Test',
          lastName: 'User',
          username: 'cleanqueen',
          phone: '555-1234',
        );

        final userDoc = await db.collection('users').doc('user-1').get();
        final data = userDoc.data();

        expect(data?['firstName'], 'Test');
        expect(data?['lastName'], 'User');
        expect(data?['username'], 'cleanqueen');
        expect(data?['email'], 'test@example.com');
        expect(data?['phone'], '555-1234');

        verify(() => user.updateDisplayName('cleanqueen')).called(1);
        verify(() => user.sendEmailVerification()).called(1);
      },
    );

    test('sendVerificationEmail sends email when user exists', () async {
      final user = MockUser();

      when(() => auth.currentUser).thenReturn(user);
      when(() => user.sendEmailVerification()).thenAnswer((_) async {});

      await service.sendVerificationEmail();

      verify(() => user.sendEmailVerification()).called(1);
    });

    test(
      'checkEmailVerified reloads user and returns verification status',
      () async {
        final user = MockUser();

        when(() => auth.currentUser).thenReturn(user);
        when(() => user.reload()).thenAnswer((_) async {});
        when(() => user.emailVerified).thenReturn(true);

        final result = await service.checkEmailVerified();

        expect(result, true);
        verify(() => user.reload()).called(1);
      },
    );

    test('sendPasswordResetEmail delegates to FirebaseAuth', () async {
      when(
        () => auth.sendPasswordResetEmail(email: 'test@example.com'),
      ).thenAnswer((_) async {});

      await service.sendPasswordResetEmail('test@example.com');

      verify(
        () => auth.sendPasswordResetEmail(email: 'test@example.com'),
      ).called(1);
    });

    test('logout signs out', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      await service.logout();

      verify(() => auth.signOut()).called(1);
    });
  });
}
