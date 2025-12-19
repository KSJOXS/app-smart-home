class NotificationModel {
  String id;
  String message;
  String type;
  DateTime timestamp;
  bool read;
  String? action;
  String? time;
  String? date;
  String? fullDateTime;
  String? user;
  String? userId;
  String? userEmail;
  String? sensor;
  dynamic value;
  String? priority;
  String? location;

  NotificationModel({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.read,
    this.action,
    this.time,
    this.date,
    this.fullDateTime,
    this.user,
    this.userId,
    this.userEmail,
    this.sensor,
    this.value,
    this.priority,
    this.location,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      read: map['read'] ?? false,
      action: map['action'],
      time: map['time'],
      date: map['date'],
      fullDateTime: map['fullDateTime'],
      user: map['user'],
      userId: map['userId'],
      userEmail: map['userEmail'],
      sensor: map['sensor'],
      value: map['value'],
      priority: map['priority'],
      location: map['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'type': type,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'read': read,
      'action': action,
      'time': time,
      'date': date,
      'fullDateTime': fullDateTime,
      'user': user,
      'userId': userId,
      'userEmail': userEmail,
      'sensor': sensor,
      'value': value,
      'priority': priority,
      'location': location,
    };
  }
}
