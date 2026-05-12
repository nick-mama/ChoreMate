import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:choremate/core/models/notification_models.dart';
import 'package:choremate/core/services/notification_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore db;
  late MockUser user;
  late NotificationService service;

  setUp(() {
    auth = MockFirebaseAuth();
    db = FakeFirebaseFirestore();
    user = MockUser();

    when(() => user.uid).thenReturn('user-1');

    service = NotificationService.testing(auth: auth, db: db);
  });

  group('NotificationService', () {
    test(
      'settingsForUser returns notification settings from user document',
      () async {
        await db.collection('users').doc('user-1').set({
          'notificationSettings': {
            'inApp': true,
            'email': false,
            'banner': true,
            'newChoreAssigned': true,
            'upcomingDeadlines': true,
            'overdueChores': true,
            'newPeopleAdded': true,
          },
        });

        final result = await service.settingsForUser('user-1');

        expect(result.inApp, true);
        expect(result.email, false);
        expect(result.banner, true);
        expect(result.newChoreAssigned, true);
      },
    );

    test('saveSettings does nothing when no user is signed in', () async {
      when(() => auth.currentUser).thenReturn(null);

      const settings = NotificationSettings();

      await service.saveSettings(settings);

      final users = await db.collection('users').get();

      expect(users.docs, isEmpty);
    });

    test('saveSettings stores settings for current user', () async {
      when(() => auth.currentUser).thenReturn(user);

      const settings = NotificationSettings(
        inApp: true,
        email: false,
        banner: true,
      );

      await service.saveSettings(settings);

      final userDoc = await db.collection('users').doc('user-1').get();
      final savedSettings = userDoc.data()?['notificationSettings'];

      expect(savedSettings['inApp'], true);
      expect(savedSettings['email'], false);
      expect(savedSettings['banner'], true);
    });

    test('markAsRead updates notification read fields', () async {
      await db.collection('notifications').doc('notification-1').set({
        'userId': 'user-1',
        'read': false,
      });

      await service.markAsRead('notification-1');

      final notificationDoc = await db
          .collection('notifications')
          .doc('notification-1')
          .get();

      expect(notificationDoc.data()?['read'], true);
      expect(notificationDoc.data()?['readAt'], isNotNull);
    });

    test('markAllAsRead does nothing when no user is signed in', () async {
      when(() => auth.currentUser).thenReturn(null);

      await db.collection('notifications').doc('notification-1').set({
        'userId': 'user-1',
        'read': false,
      });

      await service.markAllAsRead();

      final notificationDoc = await db
          .collection('notifications')
          .doc('notification-1')
          .get();

      expect(notificationDoc.data()?['read'], false);
    });

    test(
      'markAllAsRead updates every unread notification for current user',
      () async {
        when(() => auth.currentUser).thenReturn(user);

        await db.collection('notifications').doc('notification-1').set({
          'userId': 'user-1',
          'read': false,
        });

        await db.collection('notifications').doc('notification-2').set({
          'userId': 'user-1',
          'read': false,
        });

        await db.collection('notifications').doc('notification-3').set({
          'userId': 'other-user',
          'read': false,
        });

        await service.markAllAsRead();

        final first = await db
            .collection('notifications')
            .doc('notification-1')
            .get();
        final second = await db
            .collection('notifications')
            .doc('notification-2')
            .get();
        final third = await db
            .collection('notifications')
            .doc('notification-3')
            .get();

        expect(first.data()?['read'], true);
        expect(second.data()?['read'], true);
        expect(third.data()?['read'], false);
      },
    );

    test(
      'createNewChoreAssignedNotification creates notification when enabled',
      () async {
        await db.collection('users').doc('user-2').set({
          'notificationSettings': {
            'inApp': true,
            'email': false,
            'banner': true,
            'newChoreAssigned': true,
          },
        });

        await service.createNewChoreAssignedNotification(
          householdId: 'household-1',
          assignedToUserId: 'user-2',
          choreId: 'chore-1',
          choreName: 'Dishes',
          dueDate: DateTime(2026, 5, 20),
        );

        final notifications = await db.collection('notifications').get();

        expect(notifications.docs.length, 1);

        final data = notifications.docs.first.data();

        expect(data['userId'], 'user-2');
        expect(data['householdId'], 'household-1');
        expect(data['type'], 'newChoreAssigned');
        expect(data['title'], 'New chore assigned');
        expect(data['choreId'], 'chore-1');
        expect(data['read'], false);
        expect(data['body'], 'You were assigned "Dishes", due 5/20/2026.');
      },
    );

    test(
      'createNewChoreAssignedNotification does nothing when disabled',
      () async {
        await db.collection('users').doc('user-2').set({
          'notificationSettings': {
            'inApp': true,
            'email': false,
            'banner': true,
            'newChoreAssigned': false,
          },
        });

        await service.createNewChoreAssignedNotification(
          householdId: 'household-1',
          assignedToUserId: 'user-2',
          choreId: 'chore-1',
          choreName: 'Dishes',
          dueDate: null,
        );

        final notifications = await db.collection('notifications').get();

        expect(notifications.docs, isEmpty);
      },
    );

    test('deleteNotification deletes notification document', () async {
      await db.collection('notifications').doc('notification-1').set({
        'userId': 'user-1',
        'read': false,
      });

      await service.deleteNotification('notification-1');

      final notificationDoc = await db
          .collection('notifications')
          .doc('notification-1')
          .get();

      expect(notificationDoc.exists, false);
    });
  });
}
