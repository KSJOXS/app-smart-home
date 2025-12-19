import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;

  const NotificationsPage({super.key, required this.notifications});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DatabaseReference _notificationsRef = FirebaseDatabase.instance.ref(
    'notifications',
  );
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    // Filter notifications by type
    List<Map<String, dynamic>> filteredNotifications = [];

    if (_selectedFilter == 'All') {
      filteredNotifications = widget.notifications;
    } else if (_selectedFilter == 'Unread') {
      filteredNotifications =
          widget.notifications.where((n) => !(n['read'] ?? false)).toList();
    } else if (_selectedFilter == 'Alerts') {
      filteredNotifications = widget.notifications
          .where(
            (n) =>
                n['type'] == 'gas_alert' ||
                n['type'] == 'temperature_alert' ||
                n['type'] == 'security',
          )
          .toList();
    } else if (_selectedFilter == 'Voice') {
      filteredNotifications = widget.notifications
          .where(
            (n) =>
                n['type'] == 'door_voice' ||
                n['type'] == 'voice' ||
                n['type'] == 'voice_ai',
          )
          .toList();
    } else if (_selectedFilter == 'Devices') {
      filteredNotifications = widget.notifications
          .where((n) => n['type'] == 'device' || n['type'] == 'system')
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter notifications',
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showClearAllDialog,
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics bar
          if (widget.notifications.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'All',
                    widget.notifications.length.toString(),
                    Colors.teal,
                  ),
                  _buildStatItem(
                    'Unread',
                    widget.notifications
                        .where((n) => !(n['read'] ?? false))
                        .length
                        .toString(),
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'Alerts',
                    widget.notifications
                        .where(
                          (n) =>
                              n['type'] == 'gas_alert' ||
                              n['type'] == 'temperature_alert',
                        )
                        .length
                        .toString(),
                    Colors.red,
                  ),
                ],
              ),
            ),

          // Filter label
          if (_selectedFilter != 'All')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal, width: 1),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Filter: $_selectedFilter',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFilter = 'All';
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Notifications list
          Expanded(
            child: filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedFilter.toLowerCase() notifications',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilter = 'All';
                            });
                          },
                          child: const Text('View all notifications'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = filteredNotifications[index];
                      final message = notification['message'] ?? '';
                      final timestamp = notification['timestamp'];
                      final isRead = notification['read'] ?? false;
                      final type = notification['type'] ?? 'info';
                      final fullDateTime = notification['fullDateTime'] ?? '';
                      final user = notification['user'] ?? 'User';
                      final sensor = notification['sensor'] ?? '';
                      final value = notification['value'] ?? '';
                      final priority = notification['priority'] ?? 'normal';

                      DateTime dateTime;
                      if (timestamp is int) {
                        dateTime = DateTime.fromMillisecondsSinceEpoch(
                          timestamp,
                        );
                      } else {
                        dateTime = DateTime.now();
                      }

                      final timeFormat = DateFormat('HH:mm');
                      final dateFormat = DateFormat('MMM dd, yyyy');

                      Color typeColor;
                      IconData typeIcon;
                      Color backgroundColor = isRead
                          ? Colors.white
                          : (priority == 'high'
                              ? Colors.red[50]!
                              : Colors.blue[50]!);

                      switch (type) {
                        case 'door_voice':
                          typeColor = Colors.green;
                          typeIcon = Icons.door_front_door;
                          break;
                        case 'voice':
                          typeColor = Colors.purple;
                          typeIcon = Icons.mic;
                          break;
                        case 'voice_ai':
                          typeColor = Colors.amber;
                          typeIcon = Icons.auto_awesome;
                          break;
                        case 'temperature_alert':
                          typeColor = Colors.orange;
                          typeIcon = Icons.thermostat;
                          backgroundColor = Colors.orange[50]!;
                          break;
                        case 'gas_alert':
                          typeColor = Colors.red;
                          typeIcon = Icons.warning;
                          backgroundColor = Colors.red[50]!;
                          break;
                        case 'security':
                          typeColor = Colors.red;
                          typeIcon = Icons.security;
                          backgroundColor = Colors.red[50]!;
                          break;
                        case 'device':
                          typeColor = Colors.blue;
                          typeIcon = Icons.devices;
                          break;
                        case 'system':
                          typeColor = Colors.orange;
                          typeIcon = Icons.settings;
                          break;
                        default:
                          typeColor = Colors.teal;
                          typeIcon = Icons.info;
                      }

                      return Dismissible(
                        key: Key(notification['id'] ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          // Show delete confirmation
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Delete notification'),
                                content: const Text(
                                  'Are you sure you want to delete this notification?',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          _deleteNotification(notification['id']);
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: backgroundColor,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(typeIcon, color: typeColor, size: 20),
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (priority == 'high')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'ALERT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        message,
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          color: priority == 'high'
                                              ? Colors.red[800]
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        '👤 $user',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      if (sensor.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '📡 $sensor',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      fullDateTime.isNotEmpty
                                          ? fullDateTime
                                          : '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (value.toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Value: $value',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: !isRead
                                ? Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              if (!isRead) {
                                _markAsRead(notification['id']);
                              }
                              _showNotificationDetails(
                                notification,
                                user,
                                fullDateTime,
                              );
                            },
                            onLongPress: () {
                              _showNotificationDetails(
                                notification,
                                user,
                                fullDateTime,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter notifications'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('All', Icons.all_inclusive),
              _buildFilterOption('Unread', Icons.markunread),
              _buildFilterOption('Alerts', Icons.warning),
              _buildFilterOption('Voice', Icons.mic),
              _buildFilterOption('Devices', Icons.devices),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedFilter == label ? Colors.teal : Colors.grey,
      ),
      title: Text(label),
      trailing: _selectedFilter == label
          ? const Icon(Icons.check, color: Colors.teal)
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      for (var notification in widget.notifications) {
        if (!notification['read']) {
          await _notificationsRef.child(notification['id']).update({
            'read': true,
          });
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).remove();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationsRef.remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications'),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            child: const Text(
              'Clear all',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(
    Map<String, dynamic> notification,
    String userName,
    String fullDateTime,
  ) {
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'];
    final isRead = notification['read'] ?? false;
    final type = notification['type'] ?? 'info';
    final userEmail = notification['userEmail'] ?? '';
    final sensor = notification['sensor'] ?? '';
    final value = notification['value'] ?? '';
    final priority = notification['priority'] ?? 'normal';
    final location = notification['location'] ?? '';

    DateTime dateTime;
    if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      dateTime = DateTime.now();
    }

    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('MMMM dd, yyyy');

    Color typeColor;
    String typeText;
    IconData typeIcon;

    switch (type) {
      case 'door_voice':
        typeColor = Colors.green;
        typeText = 'Door control by voice';
        typeIcon = Icons.door_front_door;
        break;
      case 'gas_alert':
        typeColor = Colors.red;
        typeText = 'Gas/MQ2 alert';
        typeIcon = Icons.warning;
        break;
      case 'temperature_alert':
        typeColor = Colors.orange;
        typeText = 'Temperature alert';
        typeIcon = Icons.thermostat;
        break;
      case 'voice':
        typeColor = Colors.purple;
        typeText = 'Voice control';
        typeIcon = Icons.mic;
        break;
      case 'voice_ai':
        typeColor = Colors.amber;
        typeText = 'AI voice control';
        typeIcon = Icons.auto_awesome;
        break;
      case 'security':
        typeColor = Colors.red;
        typeText = 'Security';
        typeIcon = Icons.security;
        break;
      case 'device':
        typeColor = Colors.blue;
        typeText = 'Device';
        typeIcon = Icons.devices;
        break;
      case 'system':
        typeColor = Colors.orange;
        typeText = 'System';
        typeIcon = Icons.settings;
        break;
      default:
        typeColor = Colors.teal;
        typeText = 'Notification';
        typeIcon = Icons.info;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(typeIcon, color: typeColor),
            const SizedBox(width: 8),
            const Text('Notification Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(typeIcon, color: typeColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          typeText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (priority == 'high')
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'HIGH PRIORITY ALERT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detailed information
              _buildDetailRow('👤 Performed by:', userName),
              if (userEmail.isNotEmpty) _buildDetailRow('📧 Email:', userEmail),
              _buildDetailRow('⏰ Time:', fullDateTime),

              if (sensor.isNotEmpty) _buildDetailRow('📡 Sensor:', sensor),
              if (value.toString().isNotEmpty)
                _buildDetailRow('📊 Value:', value.toString()),
              if (location.isNotEmpty)
                _buildDetailRow('📍 Location:', location),

              const SizedBox(height: 8),
              Text(
                'System time: ${timeFormat.format(dateTime)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'System date: ${dateFormat.format(dateTime)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // ADD DANGER WARNING WHEN MQ2 = 0
              if (type == 'gas_alert' && (value == 0 || value == '0'))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dangerous, color: Colors.red[800]),
                          const SizedBox(width: 8),
                          Text(
                            '⚠️ DANGER: MQ2 SENSOR REPORTS 0',
                            style: TextStyle(
                              color: Colors.red[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sensor value = 0 indicates:',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Possible dangerous gas leak\n'
                        '• Check gas system immediately\n'
                        '• Turn off main gas valve if suspected\n'
                        '• Open ventilation immediately',
                        style: TextStyle(color: Colors.red[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Can add emergency action here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        child: const Text('EMERGENCY HANDLING'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Read status
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRead ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRead ? Icons.check_circle : Icons.markunread,
                      color: isRead ? Colors.green : Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRead ? '✅ Read' : '📬 Unread',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRead ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // MQ2 alert handling guide
              if (type == 'gas_alert')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🚨 HANDLING GUIDE:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Check MQ2 sensor connection',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '2. Ventilate kitchen area',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '3. Check gas source and stove',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Can add sensor re-check function
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Request to re-check MQ2 sensor sent',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        child: const Text('RE-CHECK SENSOR'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isRead)
            TextButton(
              onPressed: () {
                _markAsRead(notification['id']);
                Navigator.pop(context);
              },
              child: const Text('Mark as read'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ));
  }
}
