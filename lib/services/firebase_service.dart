import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Auth methods
  static Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Sign in failed');
    }
  }

  static Future<User?> registerWithEmail(
      String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      // Create user profile
      await createUserProfile(userCredential.user!, name);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Registration failed');
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Database methods
  static Future<void> createUserProfile(User user, String name) async {
    final userRef = _database.child('users/${user.uid}');
    await userRef.set({
      'name': name,
      'email': user.email,
      'phone': '',
      'address': '',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final snapshot = await _database.child('users/$userId').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    await _database.child('users/$userId').update({
      ...updates,
      'updatedAt': ServerValue.timestamp,
    });
  }

  // Device control methods
  static Future<void> setDeviceControl(String deviceId, dynamic value) async {
    await _database.child('control/$deviceId').set(value);
  }

  static Stream<DatabaseEvent> listenToDeviceControl(String deviceId) {
    return _database.child('control/$deviceId').onValue;
  }

  static Stream<DatabaseEvent> listenToSensors() {
    return _database.child('sensors').onValue;
  }

  // Notifications
  static Future<void> addNotification(Map<String, dynamic> notification) async {
    final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
    await _database.child('notifications/$notificationId').set(notification);
  }

  static Stream<DatabaseEvent> listenToNotifications() {
    return _database.child('notifications').limitToLast(50).onValue;
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await _database.child('notifications/$notificationId').update({
      'read': true,
    });
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _database.child('notifications/$notificationId').remove();
  }

  // Camera control
  static Future<void> updateCameraStatus(bool isOn) async {
    await _database.child('camera').set({
      'status': isOn ? 'on' : 'off',
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> listenToCamera() {
    return _database.child('camera').onValue;
  }
}
