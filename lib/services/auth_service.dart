import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../models/user_preferences_model.dart';

// Thrown when the user cancels re-authentication during account deletion.
class ReauthCancelledException implements Exception {
  const ReauthCancelledException();
}

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

    final trialUsed = await _wasTrialUsedBeforeDeletion(email);

    final appUser = AppUser(
      uid: user.uid,
      role: UserRole.user,
      name: name,
      surname: surname,
      email: email,
      createdAt: DateTime.now(),
      preferences: UserPreferences.defaultPreferences(),
      trialSessionUsed: trialUsed,
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
      final trialUsed = await _wasTrialUsedBeforeDeletion(user.email ?? '');
      final newUser = AppUser(
        uid: user.uid,
        role: UserRole.user,
        name: user.displayName ?? '',
        surname: '',
        email: user.email ?? '',
        createdAt: DateTime.now(),
        preferences: UserPreferences.defaultPreferences(),
        trialSessionUsed: trialUsed,
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

  /// Returns true if a previous account with this email had used the trial
  /// session before being deleted. Used to prevent trial abuse on re-signup.
  Future<bool> _wasTrialUsedBeforeDeletion(String email) async {
    final doc = await _db
        .collection('deleted_accounts')
        .doc(email.toLowerCase())
        .get();
    return doc.exists && (doc.data()?['trialSessionUsed'] as bool? ?? false);
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Delete account ────────────────────────────────────────────────────────

  /// Permanently deletes the current user's account:
  /// 1. Re-authenticates (password for email users, Google flow for OAuth).
  /// 2. Cancels all future active bookings and decrements session counts.
  /// 3. Writes an email tombstone to `deleted_accounts` if the trial was used,
  ///    so that the free-trial restriction carries over if the user re-registers.
  /// 4. Deletes the notifications sub-collection, the Firestore user doc,
  ///    and finally the Firebase Auth account.
  ///
  /// Pass [password] for email/password accounts; omit for Google accounts.
  /// Throws [ReauthCancelledException] if the user dismisses Google sign-in.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in.');

    // ── Re-authenticate ────────────────────────────────────────────────────
    if (password != null) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw const ReauthCancelledException();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }

    final uid = user.uid;
    final userRef = _db.collection('users').doc(uid);

    // ── Read trial status before deletion ──────────────────────────────────
    final userSnap = await userRef.get();
    final trialUsed = userSnap.data()?['trialSessionUsed'] as bool? ?? false;
    final email = (user.email ?? '').toLowerCase();

    // ── Cancel all future active bookings ─────────────────────────────────
    final now = Timestamp.fromDate(DateTime.now());
    final bookingsSnap = await _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .where('sessionStartsAt', isGreaterThan: now)
        .get();

    if (bookingsSnap.docs.isNotEmpty) {
      // Group cancellations by session to avoid multiple increments on the
      // same session doc inside a single batch.
      final sessionDecrements = <String, int>{};
      for (final doc in bookingsSnap.docs) {
        final sid = doc['sessionId'] as String;
        sessionDecrements[sid] = (sessionDecrements[sid] ?? 0) + 1;
      }

      final batch = _db.batch();
      for (final doc in bookingsSnap.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': Timestamp.now(),
        });
      }
      for (final entry in sessionDecrements.entries) {
        batch.update(_db.collection('sessions').doc(entry.key), {
          'bookedCount': FieldValue.increment(-entry.value),
        });
      }
      await batch.commit();
    }

    // ── Write email tombstone if trial was used ────────────────────────────
    if (trialUsed && email.isNotEmpty) {
      await _db.collection('deleted_accounts').doc(email).set({
        'email': email,
        'trialSessionUsed': true,
        'deletedAt': Timestamp.now(),
      });
    }

    // ── Delete notifications sub-collection ───────────────────────────────
    final notifSnap = await userRef.collection('notifications').get();
    if (notifSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in notifSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // ── Delete Firestore user doc and Firebase Auth account ───────────────
    await userRef.delete();
    await user.delete();
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