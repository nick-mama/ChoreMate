import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_models.dart';

class NotificationService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  NotificationService._({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final instance = NotificationService._();

  factory NotificationService.testing({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
  }) {
    return NotificationService._(db: db, auth: auth);
  }

  Stream<bool> hasUnreadNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Stream<List<AppNotification>> notificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((doc) {
            return AppNotification.fromFirestore(doc.id, doc.data());
          }).toList();

          notifications.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return bDate.compareTo(aDate);
          });

          return notifications;
        });
  }

  Future<NotificationSettings> settingsForUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return NotificationSettings.fromMap(doc.data()?['notificationSettings']);
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'notificationSettings': settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAsRead(String id) async {
    await _db.collection('notifications').doc(id).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> createNewChoreAssignedNotification({
    required String householdId,
    required String assignedToUserId,
    required String choreId,
    required String choreName,
    required DateTime? dueDate,
  }) async {
    final settings = await settingsForUser(assignedToUserId);
    if (!settings.newChoreAssigned || !settings.inApp) return;

    await _createNotification(
      userId: assignedToUserId,
      householdId: householdId,
      type: 'newChoreAssigned',
      title: 'New chore assigned',
      body: dueDate == null
          ? 'You were assigned "$choreName".'
          : 'You were assigned "$choreName", due ${_formatDate(dueDate)}.',
      choreId: choreId,
      settings: settings,
    );
  }

  Future<void> createNewHouseholdMemberNotification({
    required String householdId,
    required String addedUserId,
    required String addedUserName,
  }) async {
    final householdDoc = await _db
        .collection('households')
        .doc(householdId)
        .get();
    final householdData = householdDoc.data();
    if (householdData == null) return;

    final members = List<String>.from(householdData['members'] ?? []);

    for (final memberId in members) {
      if (memberId == addedUserId) continue;

      final settings = await settingsForUser(memberId);
      if (!settings.newPeopleAdded || !settings.inApp) continue;

      await _createNotification(
        userId: memberId,
        householdId: householdId,
        type: 'newPersonAdded',
        title: 'New household member',
        body: '$addedUserName joined your household.',
        choreId: null,
        uniqueKey: 'newPersonAdded_${householdId}_$addedUserId',
        settings: settings,
      );
    }
  }

  Future<void> checkChoreReminderNotifications({
    required String householdId,
    required String userId,
  }) async {
    final settings = await settingsForUser(userId);
    if (!settings.inApp) return;

    final choresSnapshot = await _db
        .collection('chores')
        .where('householdId', isEqualTo: householdId)
        .where('assignedTo', isEqualTo: userId)
        .where('completed', isEqualTo: false)
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in choresSnapshot.docs) {
      final data = doc.data();
      final dueDate = _readDate(data['dueDate']);
      if (dueDate == null) continue;

      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final daysUntilDue = dueDateOnly.difference(today).inDays;
      final choreName = data['name'] ?? 'Chore';

      if (settings.overdueChores && daysUntilDue < 0) {
        await _createNotificationOnce(
          userId: userId,
          householdId: householdId,
          type: 'overdueChore',
          title: 'Overdue chore',
          body: '"$choreName" is overdue.',
          choreId: doc.id,
          uniqueKey: 'overdueChore_${doc.id}_${_dateKey(today)}',
          settings: settings,
        );
      }

      if (settings.upcomingDeadlines &&
          (daysUntilDue == 7 || daysUntilDue == 3 || daysUntilDue == 1)) {
        await _createNotificationOnce(
          userId: userId,
          householdId: householdId,
          type: 'upcomingDeadline',
          title: 'Upcoming deadline',
          body:
              '"$choreName" is due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}.',
          choreId: doc.id,
          uniqueKey:
              'upcomingDeadline_${doc.id}_${daysUntilDue}_${_dateKey(today)}',
          settings: settings,
        );
      }
    }
  }

  Future<void> _createNotificationOnce({
    required String userId,
    required String householdId,
    required String type,
    required String title,
    required String body,
    required String? choreId,
    required String uniqueKey,
    required NotificationSettings settings,
  }) async {
    final existing = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('uniqueKey', isEqualTo: uniqueKey)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _createNotification(
      userId: userId,
      householdId: householdId,
      type: type,
      title: title,
      body: body,
      choreId: choreId,
      uniqueKey: uniqueKey,
      settings: settings,
    );
  }

  Future<void> _createNotification({
    required String userId,
    required String householdId,
    required String type,
    required String title,
    required String body,
    required String? choreId,
    required NotificationSettings settings,
    String? uniqueKey,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'householdId': householdId,
      'type': type,
      'title': title,
      'body': body,
      'choreId': choreId,
      'read': false,
      'uniqueKey': uniqueKey,
      'methods': {
        'inApp': settings.inApp,
        'email': settings.email,
        'banner': settings.banner,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNotification(String id) async {
    await _db.collection('notifications').doc(id).delete();
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
