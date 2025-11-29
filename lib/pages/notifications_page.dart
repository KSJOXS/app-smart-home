import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class NotificationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;

  const NotificationsPage({super.key, required this.notifications});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _markAllAsRead,
            tooltip: 'Đánh dấu tất cả đã đọc',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showClearAllDialog,
            tooltip: 'Xóa tất cả',
          ),
        ],
      ),
      body: widget.notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Không có thông báo', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('Thông báo sẽ xuất hiện ở đây', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: widget.notifications.length,
              itemBuilder: (context, index) {
                final notification = widget.notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'];
    final isRead = notification['read'] ?? false;
    final type = notification['type'] ?? 'info';

    DateTime dateTime;
    if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      dateTime = DateTime.now();
    }

    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM dd, yyyy');

    Color typeColor;
    IconData typeIcon;

    switch (type) {
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
        break;
      case 'security':
        typeColor = Colors.red;
        typeIcon = Icons.security;
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
      key: Key(notification['id'] ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification['id']);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isRead ? Colors.white : Colors.blue[50],
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          title: Text(
            message,
            style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          trailing: !isRead
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                )
              : null,
          onTap: () {
            if (!isRead) {
              _markAsRead(notification['id']);
            }
          },
          onLongPress: () => _showNotificationDetails(notification),
        ),
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await DatabaseService.markNotificationAsRead(notificationId);
    } catch (e) {
      _showError('Lỗi đánh dấu thông báo đã đọc: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      for (var notification in widget.notifications) {
        if (!notification['read']) {
          await DatabaseService.markNotificationAsRead(notification['id']);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đánh dấu tất cả thông báo đã đọc')),
        );
      }
    } catch (e) {
      _showError('Lỗi đánh dấu tất cả thông báo đã đọc: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await DatabaseService.deleteNotification(notificationId);
    } catch (e) {
      _showError('Lỗi xóa thông báo: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await DatabaseService.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tất cả thông báo')),
        );
      }
    } catch (e) {
      _showError('Lỗi xóa tất cả thông báo: $e');
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả thông báo'),
        content: const Text('Bạn có chắc chắn muốn xóa tất cả thông báo? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            child: const Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'];
    final type = notification['type'] ?? 'info';
    final isRead = notification['read'] ?? false;

    DateTime dateTime;
    if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      dateTime = DateTime.now();
    }

    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('MMMM dd, yyyy');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi tiết thông báo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tin nhắn: $message'),
            const SizedBox(height: 8),
            Text('Loại: $type'),
            const SizedBox(height: 8),
            Text('Thời gian: ${timeFormat.format(dateTime)}'),
            Text('Ngày: ${dateFormat.format(dateTime)}'),
            const SizedBox(height: 8),
            Text('Trạng thái: ${isRead ? 'Đã đọc' : 'Chưa đọc'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}