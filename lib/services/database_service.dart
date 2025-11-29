import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final DatabaseReference _controlRef = _database.child('control');
  static final DatabaseReference _sensorsRef = _database;
  static final DatabaseReference _notificationsRef = _database.child('notifications');
  static final DatabaseReference _cameraRef = _database.child('camera');

  // Control methods
  static Future<void> setControl(String key, dynamic value) async {
    try {
      await _controlRef.child(key).set(value is bool ? (value ? 'ON' : 'OFF') : value);
    } catch (e) {
      throw Exception('Control update failed: $e');
    }
  }

  static Stream<DatabaseEvent> get controlStream => _controlRef.onValue;
  static Stream<DatabaseEvent> get sensorsStream => _sensorsRef.onValue;
  static Stream<DatabaseEvent> get notificationsStream => _notificationsRef.limitToLast(50).onValue;
  static Stream<DatabaseEvent> get cameraStream => _cameraRef.onValue;

  // Notification methods
  static Future<void> addNotification(String message, String type) async {
    try {
      final String notificationId = DateTime.now().millisecondsSinceEpoch.toString();
      await _notificationsRef.child(notificationId).set({
        'message': message,
        'type': type,
        'timestamp': ServerValue.timestamp,
        'read': false,
      });
    } catch (e) {
      throw Exception('Add notification failed: $e');
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).update({'read': true});
    } catch (e) {
      throw Exception('Mark notification as read failed: $e');
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).remove();
    } catch (e) {
      throw Exception('Delete notification failed: $e');
    }
  }

  static Future<void> clearAllNotifications() async {
    try {
      await _notificationsRef.remove();
    } catch (e) {
      throw Exception('Clear all notifications failed: $e');
    }
  }

  // Camera methods
  static Future<void> startCamera() async {
    try {
      await _cameraRef.set({
        'status': 'on',
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception('Start camera failed: $e');
    }
  }

  static Future<void> stopCamera() async {
    try {
      await _cameraRef.set({
        'status': 'off',
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception('Stop camera failed: $e');
    }
  }

  // Helper methods
  static bool toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.toLowerCase();
      return s == 'on' || s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}