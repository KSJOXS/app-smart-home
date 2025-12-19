import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Control methods
  Future<void> setControl(String key, dynamic value) async {
    try {
      final formattedValue = value is bool ? (value ? 'ON' : 'OFF') : value;
      await _dbRef.child('control').child(key).set(formattedValue);
    } catch (e) {
      throw 'Lỗi gửi lệnh điều khiển: $e';
    }
  }

  Stream<Map<String, dynamic>> get controlStream {
    return _dbRef.child('control').onValue.map((event) {
      final data = event.snapshot.value;
      return data is Map ? Map<String, dynamic>.from(data) : {};
    });
  }

  // Sensors methods
  Stream<Map<String, dynamic>> get sensorsStream {
    return _dbRef.onValue.map((event) {
      final snapshotVal = event.snapshot.value;
      return snapshotVal is Map ? Map<String, dynamic>.from(snapshotVal) : {};
    });
  }

  // Notifications methods
  DatabaseReference get notificationsRef => _dbRef.child('notifications');

  Stream<List<Map<String, dynamic>>> get notificationsStream {
    return _dbRef.child('notifications').limitToLast(50).onValue.map((event) {
      final snapshotVal = event.snapshot.value;
      final List<Map<String, dynamic>> notifications = [];

      if (snapshotVal is Map) {
        snapshotVal.forEach((key, value) {
          if (value is Map) {
            final notification = Map<String, dynamic>.from(value);
            notification['id'] = key;
            notifications.add(notification);
          }
        });
      }

      notifications.sort((a, b) {
        final timestampA = a['timestamp'] ?? 0;
        final timestampB = b['timestamp'] ?? 0;
        return timestampB.compareTo(timestampA);
      });

      return notifications;
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _dbRef.child('notifications/$notificationId').update({'read': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _dbRef.child('notifications/$notificationId').remove();
  }

  // Camera methods
  Future<void> startCamera() async {
    await _dbRef.child('camera').set({
      'status': 'on',
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> stopCamera() async {
    await _dbRef.child('camera').set({
      'status': 'off',
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<Map<String, dynamic>> get cameraStream {
    return _dbRef.child('camera').onValue.map((event) {
      final data = event.snapshot.value;
      return data is Map ? Map<String, dynamic>.from(data) : {};
    });
  }

  // User methods
  DatabaseReference userRef(String uid) => _dbRef.child('users/$uid');

  Future<Map<String, dynamic>> getUserData(String uid) async {
    final snapshot = await _dbRef.child('users/$uid').get();
    return snapshot.value is Map
        ? Map<String, dynamic>.from(snapshot.value as Map)
        : {};
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _dbRef.child('users/$uid').update({
      ...data,
      'updatedAt': ServerValue.timestamp,
    });
  }
}
