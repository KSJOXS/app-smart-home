import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class FaceScanNotificationsPage extends StatefulWidget {
  const FaceScanNotificationsPage({super.key});

  @override
  State<FaceScanNotificationsPage> createState() =>
      _FaceScanNotificationsPageState();
}

class _FaceScanNotificationsPageState extends State<FaceScanNotificationsPage> {
  final DatabaseReference _faceScanRef =
      FirebaseDatabase.instance.ref('face_scan_notifications');
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('notifications');

  List<Map<String, dynamic>> _faceScanNotifications = [];
  List<Map<String, dynamic>> _combinedNotifications = [];
  bool _loading = true;
  String _selectedFilter = 'Tất cả';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFaceScanNotifications();
    _loadCombinedNotifications();
  }

  Future<void> _loadFaceScanNotifications() async {
    try {
      final snapshot = await _faceScanRef.limitToLast(50).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> notifications = [];

        data.forEach((key, value) {
          if (value is Map) {
            notifications.add({
              'id': key.toString(),
              'type': 'face_scan',
              'timestamp':
                  value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              'message': value['message'] ?? 'Phát hiện khuôn mặt',
              'confidence': value['confidence'] ?? 0.0,
              'userName': value['userName'] ?? 'Không xác định',
              'userId': value['userId'],
              'time': value['time'] ??
                  DateFormat('HH:mm:ss').format(DateTime.now()),
              'date': value['date'] ??
                  DateFormat('dd/MM/yyyy').format(DateTime.now()),
              'read': value['read'] ?? false,
              'imageCount': value['imageCount'] ?? 0,
              'registrationType': value['registrationType'] ?? 'unknown',
            });
          }
        });

        // Sắp xếp theo thời gian mới nhất
        notifications.sort(
            (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        setState(() {
          _faceScanNotifications = notifications;
          _unreadCount = notifications.where((n) => !n['read']).length;
        });
      }
    } catch (e) {
      print('Lỗi tải thông báo khuôn mặt: $e');
    }
  }

  Future<void> _loadCombinedNotifications() async {
    try {
      // Tải cả face scan và normal notifications
      final faceScanSnapshot = await _faceScanRef.limitToLast(20).get();
      final normalSnapshot = await _notificationsRef.limitToLast(20).get();

      List<Map<String, dynamic>> combined = [];

      // Thêm face scan notifications
      if (faceScanSnapshot.exists) {
        final faceData = faceScanSnapshot.value as Map<dynamic, dynamic>;
        faceData.forEach((key, value) {
          if (value is Map) {
            combined.add({
              'id': key.toString(),
              'type': 'face_scan',
              'timestamp':
                  value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              'message': value['message'] ?? 'Phát hiện khuôn mặt',
              'confidence': value['confidence'] ?? 0.0,
              'userName': value['userName'] ?? 'Không xác định',
              'userId': value['userId'],
              'read': value['read'] ?? false,
              'time': value['time'] ??
                  DateFormat('HH:mm:ss').format(DateTime.now()),
              'date': value['date'] ??
                  DateFormat('dd/MM/yyyy').format(DateTime.now()),
              'imageCount': value['imageCount'] ?? 0,
              'priority': 'high',
            });
          }
        });
      }

      // Thêm normal notifications (chỉ lấy loại security và door)
      if (normalSnapshot.exists) {
        final normalData = normalSnapshot.value as Map<dynamic, dynamic>;
        normalData.forEach((key, value) {
          if (value is Map) {
            final type = value['type']?.toString() ?? 'info';
            if (type == 'security' ||
                type == 'door_voice' ||
                type == 'gas_alert') {
              combined.add({
                'id': key.toString(),
                'type': type,
                'timestamp':
                    value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
                'message': value['message'] ?? '',
                'userName': value['user'] ?? 'Hệ thống',
                'read': value['read'] ?? false,
                'time': value['time'] ?? '',
                'date': value['date'] ?? '',
                'priority': type == 'gas_alert' ? 'high' : 'medium',
                'sensor': value['sensor'] ?? '',
                'value': value['value'] ?? '',
              });
            }
          }
        });
      }

      // Sắp xếp theo thời gian
      combined.sort(
          (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      setState(() {
        _combinedNotifications = combined;
        _loading = false;
      });
    } catch (e) {
      print('Lỗi tải thông báo kết hợp: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId,
      {bool isFaceScan = true}) async {
    try {
      if (isFaceScan) {
        await _faceScanRef.child(notificationId).update({'read': true});
      } else {
        await _notificationsRef.child(notificationId).update({'read': true});
      }

      // Reload data
      _loadFaceScanNotifications();
      _loadCombinedNotifications();
    } catch (e) {
      print('Lỗi đánh dấu đã đọc: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      for (var notification in _faceScanNotifications) {
        if (!notification['read']) {
          await _faceScanRef.child(notification['id']).update({'read': true});
        }
      }

      // Reload
      _loadFaceScanNotifications();
      _loadCombinedNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đánh dấu tất cả thông báo đã đọc')),
        );
      }
    } catch (e) {
      print('Lỗi đánh dấu tất cả đã đọc: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId,
      {bool isFaceScan = true}) async {
    try {
      if (isFaceScan) {
        await _faceScanRef.child(notificationId).remove();
      } else {
        await _notificationsRef.child(notificationId).remove();
      }

      // Reload
      _loadFaceScanNotifications();
      _loadCombinedNotifications();
    } catch (e) {
      print('Lỗi xóa thông báo: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    if (_selectedFilter == 'Tất cả') {
      return _combinedNotifications;
    } else if (_selectedFilter == 'Khuôn mặt') {
      return _combinedNotifications
          .where((n) => n['type'] == 'face_scan')
          .toList();
    } else if (_selectedFilter == 'Chưa đọc') {
      return _combinedNotifications.where((n) => !n['read']).toList();
    } else if (_selectedFilter == 'Cảnh báo') {
      return _combinedNotifications
          .where((n) => n['type'] == 'gas_alert' || n['priority'] == 'high')
          .toList();
    } else if (_selectedFilter == 'Truy cập') {
      return _combinedNotifications
          .where((n) => n['type'] == 'door_voice' || n['type'] == 'security')
          .toList();
    }
    return _combinedNotifications;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc thông báo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('Tất cả', Icons.all_inclusive),
              _buildFilterOption('Khuôn mặt', Icons.face),
              _buildFilterOption('Chưa đọc', Icons.markunread),
              _buildFilterOption('Cảnh báo', Icons.warning),
              _buildFilterOption('Truy cập', Icons.security),
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

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final type = notification['type'] ?? 'info';
    final message = notification['message'] ?? '';
    final userName = notification['userName'] ?? 'Không xác định';
    final confidence = notification['confidence'] ?? 0.0;
    final isRead = notification['read'] ?? false;
    final timestamp = notification['timestamp'];
    final time = notification['time'] ?? '';
    final date = notification['date'] ?? '';
    final priority = notification['priority'] ?? 'medium';
    final imageCount = notification['imageCount'] ?? 0;

    DateTime dateTime;
    if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      dateTime = DateTime.now();
    }

    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');

    Color typeColor;
    IconData typeIcon;
    String typeText;

    switch (type) {
      case 'face_scan':
        typeColor = Colors.purple;
        typeIcon = Icons.face;
        typeText = 'Quét khuôn mặt';
        break;
      case 'door_voice':
        typeColor = Colors.green;
        typeIcon = Icons.door_front_door;
        typeText = 'Điều khiển cửa';
        break;
      case 'security':
        typeColor = Colors.red;
        typeIcon = Icons.security;
        typeText = 'Bảo mật';
        break;
      case 'gas_alert':
        typeColor = Colors.orange;
        typeIcon = Icons.warning;
        typeText = 'Cảnh báo khí gas';
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.notifications;
        typeText = 'Thông báo';
    }

    return Dismissible(
      key: Key('${notification['id']}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa thông báo'),
            content: const Text('Bạn có chắc chắn muốn xóa thông báo này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteNotification(
          notification['id'],
          isFaceScan: type == 'face_scan',
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isRead
            ? Colors.white
            : (priority == 'high' ? Colors.red[50] : Colors.blue[50]),
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
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'CẢNH BÁO',
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
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.bold,
                        color:
                            priority == 'high' ? Colors.red[800] : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '👤 $userName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (type == 'face_scan' && confidence > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Độ tin cậy: ${(confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    time.isNotEmpty && date.isNotEmpty
                        ? '$time - $date'
                        : '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (type == 'face_scan' && imageCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Text(
                          '📸 $imageCount ảnh',
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
              _markAsRead(
                notification['id'],
                isFaceScan: type == 'face_scan',
              );
            }
            _showNotificationDetails(notification);
          },
          onLongPress: () {
            _showNotificationDetails(notification);
          },
        ),
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final type = notification['type'] ?? 'info';
    final message = notification['message'] ?? '';
    final userName = notification['userName'] ?? 'Không xác định';
    final confidence = notification['confidence'] ?? 0.0;
    final time = notification['time'] ?? '';
    final date = notification['date'] ?? '';
    final priority = notification['priority'] ?? 'medium';
    final imageCount = notification['imageCount'] ?? 0;
    final registrationType = notification['registrationType'] ?? 'unknown';
    final sensor = notification['sensor'] ?? '';
    final value = notification['value'] ?? '';

    Color typeColor;
    IconData typeIcon;
    String typeText;

    switch (type) {
      case 'face_scan':
        typeColor = Colors.purple;
        typeIcon = Icons.face;
        typeText = 'Thông báo Quét Khuôn mặt';
        break;
      case 'door_voice':
        typeColor = Colors.green;
        typeIcon = Icons.door_front_door;
        typeText = 'Thông báo Điều khiển Cửa';
        break;
      case 'security':
        typeColor = Colors.red;
        typeIcon = Icons.security;
        typeText = 'Thông báo Bảo mật';
        break;
      case 'gas_alert':
        typeColor = Colors.orange;
        typeIcon = Icons.warning;
        typeText = 'Cảnh báo Khí gas';
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.notifications;
        typeText = 'Thông báo Hệ thống';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(typeIcon, color: typeColor),
            const SizedBox(width: 8),
            const Text('Chi tiết thông báo'),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('👤 Người dùng:', userName),
              _buildDetailRow('⏰ Thời gian:', '$time - $date'),
              if (type == 'face_scan') ...[
                _buildDetailRow('🎯 Loại đăng ký:', registrationType),
                _buildDetailRow('📊 Độ tin cậy:',
                    '${(confidence * 100).toStringAsFixed(1)}%'),
                _buildDetailRow('📸 Số lượng ảnh:', '$imageCount ảnh'),
                const SizedBox(height: 8),
                if (confidence > 0.8)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✅ Khuôn mặt được xác thực thành công với độ tin cậy cao',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
              ],
              if (type == 'gas_alert') ...[
                _buildDetailRow('📡 Cảm biến:', sensor),
                _buildDetailRow('📊 Giá trị:', value.toString()),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Cần kiểm tra hệ thống gas và thông gió khu vực',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (!(notification['read'] ?? false))
            TextButton(
              onPressed: () {
                _markAsRead(
                  notification['id'],
                  isFaceScan: type == 'face_scan',
                );
                Navigator.pop(context);
              },
              child: const Text('Đánh dấu đã đọc'),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo Bảo mật'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Lọc thông báo',
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _markAllAsRead,
            tooltip: 'Đánh dấu tất cả đã đọc',
          ),
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text(
                  _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thống kê
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                          'Tổng',
                          _combinedNotifications.length.toString(),
                          Colors.purple),
                      _buildStatItem(
                          'Khuôn mặt',
                          _faceScanNotifications.length.toString(),
                          Colors.purple),
                      _buildStatItem(
                          'Chưa đọc', _unreadCount.toString(), Colors.blue),
                    ],
                  ),
                ),

                // Bộ lọc đang chọn
                if (_selectedFilter != 'Tất cả')
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.purple, width: 1),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Bộ lọc: $_selectedFilter',
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = 'Tất cả';
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Danh sách thông báo
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
                                'Không có thông báo $_selectedFilter.toLowerCase()',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadFaceScanNotifications();
                            await _loadCombinedNotifications();
                          },
                          child: ListView.builder(
                            itemCount: filteredNotifications.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationItem(
                                  filteredNotifications[index], index);
                            },
                          ),
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
}
