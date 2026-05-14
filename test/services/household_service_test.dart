import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:choremate/core/services/household_service.dart';
import 'package:choremate/core/services/notification_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore db;
  late MockNotificationService notifications;
  late MockUser user;
  late HouseholdService service;

  setUp(() {
    auth = MockFirebaseAuth();
    db = FakeFirebaseFirestore();
    notifications = MockNotificationService();
    user = MockUser();

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('user-1');
    when(() => user.email).thenReturn('user@example.com');

    service = HouseholdService(
      auth: auth,
      db: db,
      notificationService: notifications,
    );
  });

  group('HouseholdService', () {
    test(
      'createHousehold creates household and updates user householdId',
      () async {
        await db.collection('users').doc('user-1').set({
          'email': 'user@example.com',
        });

        final result = await service.createHousehold(
          'Apartment',
          householdType: 'roommates',
        );

        final householdId = result['householdId'];

        final householdDoc = await db
            .collection('households')
            .doc(householdId)
            .get();
        final userDoc = await db.collection('users').doc('user-1').get();

        expect(householdDoc.exists, true);
        expect(householdDoc.data()?['name'], 'Apartment');
        expect(householdDoc.data()?['householdType'], 'roommates');
        expect(householdDoc.data()?['ownerId'], 'user-1');
        expect(householdDoc.data()?['createdBy'], 'user-1');
        expect(householdDoc.data()?['members'], ['user-1']);
        expect(householdDoc.data()?['memberRoles'], {'user-1': 'owner'});
        expect(householdDoc.data()?['inviteCode'], isA<String>());
        expect(userDoc.data()?['householdId'], result['householdId']);
      },
    );

    test('joinByCode throws when invite code is invalid', () async {
      expect(() => service.joinByCode('abc123'), throwsA(isA<Exception>()));
    });

    test(
      'joinByCode adds user to household and creates notification',
      () async {
        await db.collection('users').doc('user-1').set({
          'username': 'cleanqueen',
          'email': 'user@example.com',
        });

        await db.collection('households').doc('household-1').set({
          'name': 'Apartment',
          'inviteCode': 'ABC123',
          'members': ['owner-1'],
          'memberRoles': {'owner-1': 'owner'},
        });

        when(
          () => notifications.createNewHouseholdMemberNotification(
            householdId: 'household-1',
            addedUserId: 'user-1',
            addedUserName: 'cleanqueen',
          ),
        ).thenAnswer((_) async {});

        await service.joinByCode('abc123');

        final householdDoc = await db
            .collection('households')
            .doc('household-1')
            .get();
        final userDoc = await db.collection('users').doc('user-1').get();

        expect(householdDoc.data()?['members'], contains('user-1'));
        expect(householdDoc.data()?['memberRoles']['user-1'], 'member');
        expect(userDoc.data()?['householdId'], 'household-1');

        verify(
          () => notifications.createNewHouseholdMemberNotification(
            householdId: 'household-1',
            addedUserId: 'user-1',
            addedUserName: 'cleanqueen',
          ),
        ).called(1);
      },
    );

    test(
      'getCurrentHouseholdId returns householdId from current user document',
      () async {
        await db.collection('users').doc('user-1').set({
          'householdId': 'household-1',
        });

        final result = await service.getCurrentHouseholdId();

        expect(result, 'household-1');
      },
    );

    test('getHousehold returns household data', () async {
      await db.collection('households').doc('household-1').set({
        'name': 'Apartment',
      });

      final result = await service.getHousehold('household-1');

      expect(result?['name'], 'Apartment');
    });

    test('getCurrentUserRole returns role from memberRoles', () async {
      await db.collection('households').doc('household-1').set({
        'memberRoles': {'user-1': 'admin'},
      });

      final result = await service.getCurrentUserRole('household-1');

      expect(result, 'admin');
    });

    test(
      'getCurrentUserRole falls back to owner when user created household',
      () async {
        await db.collection('households').doc('household-1').set({
          'createdBy': 'user-1',
        });

        final result = await service.getCurrentUserRole('household-1');

        expect(result, 'owner');
      },
    );
  });
}
