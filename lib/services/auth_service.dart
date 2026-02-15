import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// =============================
  /// EMAIL + PASSWORD REGISTER
  /// =============================
  Future<User?> registerWithEmail({
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

    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'role': 'user',
        'name': name,
        'surname': surname,
        'email': email,
        'createdAt': Timestamp.now(),
        'promotion': null,
        'preferences': {},
      });
    }

    return user;
  }

  /// =============================
  /// EMAIL + PASSWORD LOGIN
  /// =============================
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return credential.user;
  }

  /// =============================
  /// GOOGLE LOGIN
  /// =============================
  Future<User?> signInWithGoogle() async {
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

    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'role': 'user',
          'name': user.displayName ?? '',
          'surname': '',
          'email': user.email ?? '',
          'createdAt': Timestamp.now(),
          'promotion': null,
          'preferences': {},
        });
      }
    }

    return user;
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

  User? get currentUser => _auth.currentUser;
}
