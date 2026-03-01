import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../models/user_preferences_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// =============================
  /// EMAIL + PASSWORD REGISTER
  /// =============================
  Future<AppUser> registerWithEmail({
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

    if (user == null) {
      throw Exception("User creation failed.");
    }

    final appUser = AppUser(
      uid: user.uid,
      role: UserRole.user,
      name: name,
      surname: surname,
      email: email,
      createdAt: DateTime.now(),
      promotion: null,
      preferences: UserPreferences.defaultPreferences(),
    );

    await _db.collection('users').doc(user.uid).set(appUser.toMap());

    return appUser;
  }

  /// =============================
  /// EMAIL + PASSWORD LOGIN
  /// =============================
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception("Login failed.");
    }

    return await _getUserFromFirestore(user.uid);
  }

  /// =============================
  /// GOOGLE LOGIN
  /// =============================
  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser =
        await _googleSignIn.signIn();

    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user == null) {
      throw Exception("Google authentication failed.");
    }

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      final newUser = AppUser(
        uid: user.uid,
        role: UserRole.user,
        name: user.displayName ?? '',
        surname: '',
        email: user.email ?? '',
        createdAt: DateTime.now(),
        promotion: null,
        preferences: UserPreferences.defaultPreferences(),
      );

      await _db.collection('users').doc(user.uid).set(newUser.toMap());
      return newUser;
    }

    return AppUser.fromFirestore(doc);
  }

  /// =============================
  /// FETCH USER FROM FIRESTORE
  /// =============================
  Future<AppUser> _getUserFromFirestore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) {
      throw Exception("User document does not exist.");
    }

    return AppUser.fromFirestore(doc);
  }

  /// =============================
  /// RESET PASSWORD
  /// =============================
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// =============================
  /// SIGN OUT
  /// =============================
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// =============================
  /// AUTH STATE STREAM
  /// =============================
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  User? get currentFirebaseUser => _auth.currentUser;
}