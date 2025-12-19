import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<User?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _createUserProfileIfNotExists(userCredential.user!);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Đăng nhập thất bại';
    }
  }

  Future<User?> signUp(String name, String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user!.updateDisplayName(name);
      await _createUserProfile(userCredential.user!, name);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Đăng ký thất bại';
    }
  }

  Future<void> _createUserProfileIfNotExists(User user) async {
    final userRef = _dbRef.child('users/${user.uid}');
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await _createUserProfile(user, user.displayName ?? 'Người dùng');
    }
  }

  Future<void> _createUserProfile(User user, String name) async {
    final userRef = _dbRef.child('users/${user.uid}');
    await userRef.set({
      'name': name,
      'email': user.email,
      'phone': '',
      'address': '',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
