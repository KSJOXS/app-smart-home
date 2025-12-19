import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('notifications');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addDoorNotification(String action, String command) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await _getUserData(user.uid);
    final notification = await _createNotification(
      type: 'door_voice',
      message: '$action cửa bằng giọng nói - "$command"',
      action: action,
      userData: userData,
      sensor: 'Voice Command',
      value: command,
    );

    await _notificationsRef.child(notification.id).set(notification.toMap());
  }

  Future<void> addGasAlertNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await _getUserData(user.uid);
    final notification = await _createNotification(
      type: 'gas_alert',
      message: '🚨 NGUY HIỂM',
      userData: userData,
      sensor: 'MQ2',
      value: 0,
      priority: 'high',
    );

    await _notificationsRef.child(notification.id).set(notification.toMap());
  }

  Future<void> addTemperatureAlert(double temperature) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await _getUserData(user.uid);
    final notification = await _createNotification(
      type: 'temperature_alert',
      message:
          '🚨 Nhiệt độ cao: ${temperature.toStringAsFixed(1)}°C. Hãy bật quạt hoặc điều hòa.',
      userData: userData,
      sensor: 'Temperature',
      value: temperature,
      priority: 'medium',
    );

    await _notificationsRef.child(notification.id).set(notification.toMap());
  }

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$uid').get();
    return snapshot.exists && snapshot.value is Map
        ? Map<String, dynamic>.from(snapshot.value as Map)
        : {};
  }

  Future<NotificationModel> _createNotification({
    required String type,
    required String message,
    String? action,
    required Map<String, dynamic> userData,
    String? sensor,
    dynamic value,
    String priority = 'normal',
  }) async {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return NotificationModel(
      id: now.millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      timestamp: now,
      read: false,
      action: action,
      time: timeFormat.format(now),
      date: dateFormat.format(now),
      fullDateTime: '${timeFormat.format(now)} - ${dateFormat.format(now)}',
      user: userData['name'] ?? 'Người dùng',
      userId: _auth.currentUser?.uid,
      userEmail: _auth.currentUser?.email,
      sensor: sensor,
      value: value,
      priority: priority,
    );
  }
}
