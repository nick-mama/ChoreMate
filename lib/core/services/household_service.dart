import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class HouseholdService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final NotificationService _notifications;

  HouseholdService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _notifications = notificationService ?? NotificationService.instance;

  String get _uid => _auth.currentUser!.uid;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Map<String, String>> createHousehold(
    String name, {
    required String householdType,
  }) async {
    final inviteCode = _generateInviteCode();

    final doc = await _db.collection('households').add({
      'name': name,
      'inviteCode': inviteCode,
      'householdType': householdType,
      'ownerId': _uid,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [_uid],
      'memberRoles': {_uid: 'owner'},
    });

    await _db.collection('users').doc(_uid).update({'householdId': doc.id});

    return {'householdId': doc.id, 'inviteCode': inviteCode};
  }

  Future<void> joinByCode(String code) async {
    final query = await _db
        .collection('households')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code.');
    }

    final householdDoc = query.docs.first;
    final userDoc = await _db.collection('users').doc(_uid).get();
    final userData = userDoc.data() ?? {};
    final addedUserName =
        userData['username'] ??
        userData['email'] ??
        _auth.currentUser?.email ??
        'Someone';

    await householdDoc.reference.update({
      'members': FieldValue.arrayUnion([_uid]),
      'memberRoles.$_uid': 'member',
    });

    await _db.collection('users').doc(_uid).update({
      'householdId': householdDoc.id,
    });

    await _notifications.createNewHouseholdMemberNotification(
      householdId: householdDoc.id,
      addedUserId: _uid,
      addedUserName: addedUserName,
    );
  }

  Future<void> inviteByEmail(String email, String householdId) async {
    final userQuery = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('No user found with that email.');
    }

    final invitedUid = userQuery.docs.first.id;
    final invitedUser = userQuery.docs.first.data();

    if (invitedUser['householdId'] != null &&
        invitedUser['householdId'].isNotEmpty) {
      throw Exception('That user is already in a household.');
    }

    final addedUserName =
        invitedUser['username'] ?? invitedUser['email'] ?? 'Someone';

    await _db.collection('households').doc(householdId).update({
      'members': FieldValue.arrayUnion([invitedUid]),
      'memberRoles.$invitedUid': 'member',
    });

    await _db.collection('users').doc(invitedUid).update({
      'householdId': householdId,
    });

    await _notifications.createNewHouseholdMemberNotification(
      householdId: householdId,
      addedUserId: invitedUid,
      addedUserName: addedUserName,
    );
  }

  Future<String?> getCurrentHouseholdId() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data()?['householdId'] as String?;
  }

  Future<Map<String, dynamic>?> getHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    return doc.data();
  }

  Future<String> getCurrentUserRole(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    final data = doc.data();

    final roles = data?['memberRoles'];
    if (roles is Map && roles[_uid] is String) {
      return roles[_uid] as String;
    }

    if (data?['ownerId'] == _uid || data?['createdBy'] == _uid) {
      return 'owner';
    }

    return 'member';
  }

  Future<String?> getCurrentInviteCode() async {
    final householdId = await getCurrentHouseholdId();

    if (householdId == null || householdId.isEmpty) {
      return null;
    }

    final doc = await _db.collection('households').doc(householdId).get();
    final data = doc.data();

    return data?['inviteCode'] as String?;
  }
}
