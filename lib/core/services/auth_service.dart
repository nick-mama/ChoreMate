import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_repository.dart';

class AuthService implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<UserCredential> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _syncDisplayNameIfMissing();

    return credential;
  }

  Future<void> _syncDisplayNameIfMissing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (user.displayName == null || user.displayName!.isEmpty) {
      final doc = await _db.collection('users').doc(user.uid).get();

      final username = doc.data()?['username'];

      if (username != null) {
        await user.updateDisplayName(username);
        await user.reload();
      }
    }
  }

  @override
  Future<void> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    String? phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user!.updateDisplayName(username);

    final uid = credential.user!.uid;

    await _db.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'phone': phone ?? '',
      'householdId': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await credential.user!.sendEmailVerification();
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }
}
