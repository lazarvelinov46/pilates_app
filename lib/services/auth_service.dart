import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../models/user_preferences_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Email verification ────────────────────────────────────────────────────

  /// Creates the Firebase Auth account, sends a verification email,
  /// and writes the Firestore user document.
  Future<void> registerAndSendVerification({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception('User creation failed.');

    await user.updateDisplayName('$name $surname');
    await user.sendEmailVerification();

    final appUser = AppUser(
      uid: user.uid,
      role: UserRole.user,
      name: name,
      surname: surname,
      email: email,
      createdAt: DateTime.now(),
      preferences: UserPreferences.defaultPreferences(),
    );

    await _db.collection('users').doc(user.uid).set(appUser.toMap());
  }

  /// Reloads the Firebase Auth token and checks the verified flag.
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Resends the verification email. Firebase rate-limits this automatically.
  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in.');
    await user.sendEmailVerification();
  }

  // ── Email + password login ────────────────────────────────────────────────

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception('Login failed.');

    return await _getUserFromFirestore(user.uid);
  }

  // ── Google login ──────────────────────────────────────────────────────────

  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) throw Exception('Google authentication failed.');

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      final newUser = AppUser(
        uid: user.uid,
        role: UserRole.user,
        name: user.displayName ?? '',
        surname: '',
        email: user.email ?? '',
        createdAt: DateTime.now(),
        preferences: UserPreferences.defaultPreferences(),
      );
      await _db.collection('users').doc(user.uid).set(newUser.toMap());
      return newUser;
    }

    return AppUser.fromFirestore(doc);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<AppUser> _getUserFromFirestore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User document does not exist.');
    return AppUser.fromFirestore(doc);
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Auth state ────────────────────────────────────────────────────────────

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await _getUserFromFirestore(user.uid);
  }

  User? get currentFirebaseUser => _auth.currentUser;
}