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
  Future<UserCredential> login(String input, String password) async {
    final normalizedInput = input.trim().toLowerCase();

    String email = normalizedInput;

    if (!normalizedInput.contains('@')) {
      final usernameDoc = await _db
          .collection('usernames')
          .doc(normalizedInput)
          .get();

      if (!usernameDoc.exists) {
        throw FirebaseAuthException(code: 'account-not-found');
      }

      final uid = usernameDoc.data()?['uid'];

      if (uid == null) {
        throw FirebaseAuthException(code: 'account-not-found');
      }

      final userDoc = await _db.collection('users').doc(uid).get();
      final userEmail = userDoc.data()?['email'];

      if (userEmail == null) {
        throw FirebaseAuthException(code: 'account-not-found');
      }

      email = userEmail;
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _syncDisplayNameIfMissing();
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(code: 'account-not-found');
      }
      rethrow;
    }
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
    final normalizedUsername = username.trim().toLowerCase();
    final usernameRef = _db.collection('usernames').doc(normalizedUsername);

    var usernameReserved = false;

    try {
      await _db.runTransaction((transaction) async {
        final usernameSnapshot = await transaction.get(usernameRef);

        if (usernameSnapshot.exists) {
          throw FirebaseAuthException(
            code: 'username-already-in-use',
            message: 'Username already taken.',
          );
        }

        transaction.set(usernameRef, {
          'reservedAt': FieldValue.serverTimestamp(),
        });
      });

      usernameReserved = true;

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.updateDisplayName(normalizedUsername);

      final uid = credential.user!.uid;

      await _db.collection('users').doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'username': normalizedUsername,
        'email': email,
        'phone': phone ?? '',
        'householdId': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await usernameRef.set({
        'uid': uid,
        'reservedAt': FieldValue.serverTimestamp(),
      });

      await credential.user!.sendEmailVerification();
    } catch (e) {
      if (usernameReserved) {
        await usernameRef.delete();
      }

      rethrow;
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
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
