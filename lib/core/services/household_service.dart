import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> createHousehold(String name) async {
    final inviteCode = _generateInviteCode();

    final doc = await _db.collection('households').add({
      'name': name,
      'inviteCode': inviteCode,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [_uid],
    });

    await _db.collection('users').doc(_uid).update({'householdId': doc.id});

    return doc.id;
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

    await householdDoc.reference.update({
      'members': FieldValue.arrayUnion([_uid]),
    });

    await _db.collection('users').doc(_uid).update({
      'householdId': householdDoc.id,
    });
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

    await _db.collection('households').doc(householdId).update({
      'members': FieldValue.arrayUnion([invitedUid]),
    });

    await _db.collection('users').doc(invitedUid).update({
      'householdId': householdId,
    });
  }

  Future<String?> getCurrentHouseholdId() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data()?['householdId'] as String?;
  }

  Future<Map<String, dynamic>?> getHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    return doc.data();
  }
}
