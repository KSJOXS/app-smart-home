import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../services/auth_service.dart';
import 'notifications_page.dart';
import 'camera_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VoiceService _voiceService = VoiceService();
  
  // Device states
  bool isDoorOn = false;
  bool isLivingLightOn = false;
  bool isBedroomLightOn = false;
  bool isBathroomLightOn = false;
  bool isFanOn = false;

  // Sensors
  double? temperature;
  double? humidity;

  // Notifications
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupListeners();
  }

  Future<void> _initializeServices() async {
    await _voiceService.init();
    _voiceService.setOnResultCallback(_handleVoiceResult);
  }

  void _setupListeners() {
    DatabaseService.controlStream.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          isLivingLightOn = DatabaseService.toBool(data['led1']);
          isBedroomLightOn = DatabaseService.toBool(data['led2']);
          isBathroomLightOn = DatabaseService.toBool(data['led3']);
          isFanOn = DatabaseService.toBool(data['motor']);
          final angle = data['servo_angle'];
          isDoorOn = (angle != "0");
        });
      }
    });

    DatabaseService.sensorsStream.listen((event) {
      final snapshotVal = event.snapshot.value;
      if (snapshotVal is Map && mounted) {
        setState(() {
          final sensorsData = snapshotVal['sensors'] ?? snapshotVal;
          temperature = DatabaseService.toDouble(sensorsData['temperature']);
          humidity = DatabaseService.toDouble(sensorsData['humidity']);
        });
        _checkTemperatureAlert(temperature);
      }
    });

    DatabaseService.notificationsStream.listen((event) {
      final snapshotVal = event.snapshot.value;
      if (snapshotVal is Map && mounted) {
        _notifications.clear();
        int unreadCount = 0;

        snapshotVal.forEach((key, value) {
          if (value is Map) {
            final notification = {
              'id': key,
              'message': value['message'] ?? '',
              'type': value['type'] ?? 'info',
              'timestamp': value['timestamp'],
              'read': value['read'] ?? false,
            };
            _notifications.insert(0, notification);
            if (!(value['read'] ?? false)) {
              unreadCount++;
            }
          }
        });

        setState(() {
          _unreadNotifications = unreadCount;
          if (_notifications.length > 50) _notifications.removeLast();
        });
      }
    });
  }

  // Xử lý kết quả từ voice service
  void _handleVoiceResult(Map<String, dynamic> result) {
    if (result['success'] == true) {
      _executeVoiceCommand(result);
    } else {
      // Hiển thị thông báo lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Không nhận diện được lệnh nói'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _checkTemperatureAlert(double? temp) {
    if (temp != null && temp > 30) {
      DatabaseService.addNotification(
        '🚨 Nhiệt độ cao: ${temp.toStringAsFixed(1)}°C. Hãy bật quạt hoặc điều hòa.',
        'temperature_alert',
      );
    }
  }

  Future<void> _executeVoiceCommand(Map<String, dynamic> commandData) async {
    final String command = commandData['command'];
    final double confidence = commandData['confidence'];

    String feedback = 'Lệnh đã được thực thi';

    switch (command) {
      case 'bat_quat':
        await DatabaseService.setControl('motor', true);
        feedback = 'Đã bật quạt';
        break;
      case 'tat_quat':
        await DatabaseService.setControl('motor', false);
        feedback = 'Đã tắt quạt';
        break;
      case 'bat_tat_ca':
        await DatabaseService.setControl('led1', true);
        await DatabaseService.setControl('led2', true);
        await DatabaseService.setControl('led3', true);
        await DatabaseService.setControl('motor', true);
        feedback = 'Đã bật tất cả thiết bị';
        break;
      case 'tat_tat_ca':
        await DatabaseService.setControl('led1', false);
        await DatabaseService.setControl('led2', false);
        await DatabaseService.setControl('led3', false);
        await DatabaseService.setControl('motor', false);
        feedback = 'Đã tắt tất cả thiết bị';
        break;
      case 'bat_den_phong_khach':
        await DatabaseService.setControl('led1', true);
        feedback = 'Đã bật đèn phòng khách';
        break;
      case 'tat_den_phong_khach':
        await DatabaseService.setControl('led1', false);
        feedback = 'Đã tắt đèn phòng khách';
        break;
      case 'bat_den_phong_ngu':
        await DatabaseService.setControl('led2', true);
        feedback = 'Đã bật đèn phòng ngủ';
        break;
      case 'tat_den_phong_ngu':
        await DatabaseService.setControl('led2', false);
        feedback = 'Đã tắt đèn phòng ngủ';
        break;
      case 'bat_den_phong_bep':
        await DatabaseService.setControl('led3', true);
        feedback = 'Đã bật đèn phòng bếp';
        break;
      case 'tat_den_phong_bep':
        await DatabaseService.setControl('led3', false);
        feedback = 'Đã tắt đèn phòng bếp';
        break;
      default:
        feedback = 'Không hiểu lệnh';
    }

    // Add notification
    if (command != 'unknown') {
      await DatabaseService.addNotification(
        'Lệnh giọng nói (CNN): $command (${(confidence * 100).toStringAsFixed(1)}%)',
        'voice_cnn',
      );
    }

    if (mounted && command != 'unknown') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.yellow[700]),
              const SizedBox(width: 8),
              Text('$feedback (${(confidence * 100).toStringAsFixed(1)}%)'),
            ],
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Navigation methods
  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsPage(notifications: _notifications),
      ),
    );
  }

  void _navigateToCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraStreamPage()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                AuthService.logout();
              },
              child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Utility methods
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng,';
    if (hour < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  String getFormattedDate() {
    final now = DateTime.now();
    final months = [
      '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
  }

  String getTempLabel(double? temp) {
    if (temp == null) return '';
    if (temp > 25) return 'Ấm';
    if (temp > 20) return 'Thoải mái';
    return 'Mát';
  }

  String getHumidityLabel(double? hum) {
    if (hum == null) return '';
    if (hum > 60) return 'Cao';
    if (hum > 40) return 'Bình thường';
    return 'Thấp';
  }

  // Voice control methods
  Future<void> _startListening() async {
    await _voiceService.startRecording();
    setState(() {});
  }

  Future<void> _stopListening() async {
    await _voiceService.stopRecording();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(getGreeting(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Nhà Thông Minh',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.videocam),
                      onPressed: _navigateToCamera,
                      tooltip: 'Camera',
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: _navigateToNotifications,
                          tooltip: 'Thông báo',
                        ),
                        if (_unreadNotifications > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: _navigateToSettings,
                      tooltip: 'Cài đặt',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Location and Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tại Đà Nẵng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(getFormattedDate(), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Temperature and Humidity Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: const Color(0x3300BFA6),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nhiệt độ'),
                          Text(
                            temperature != null ? '${temperature!.toStringAsFixed(0)}°' : '--',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          Text(getTempLabel(temperature)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: const Color(0x3300BFA6),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Độ ẩm'),
                          Text(
                            humidity != null ? '${humidity!.toStringAsFixed(0)}%' : '--',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          Text(getHumidityLabel(humidity)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Device List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // AI Voice Model Status
                Card(
                  child: ListTile(
                    leading: Icon(
                      _voiceService.isModelLoaded ? Icons.check_circle : Icons.error,
                      color: _voiceService.isModelLoaded ? Colors.green : Colors.orange,
                    ),
                    title: const Text('Nhận dạng giọng nói AI'),
                    subtitle: Text(_voiceService.isModelLoaded
                        ? 'Model CNN đã sẵn sàng (10 lớp)'
                        : 'Đang tải model...'),
                    trailing: _voiceService.isRecording 
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ĐANG GHI ÂM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Camera Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Camera An ninh',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Trực tiếp', style: TextStyle(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.videocam, size: 40, color: Colors.blue),
                    title: const Text('Camera An ninh', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Giám sát nhà'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Xem trực tiếp'),
                      onPressed: _navigateToCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Smart Devices Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Thiết bị Thông minh',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Làm mới', style: TextStyle(color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),

                // Master Switch for all devices
                Card(
                  child: SwitchListTile(
                    title: const Text('Tất cả thiết bị'),
                    value: isDoorOn && isLivingLightOn && isBedroomLightOn && isBathroomLightOn && isFanOn,
                    onChanged: (bool value) async {
                      await DatabaseService.setControl('servo_angle', value ? '90' : '0');
                      await DatabaseService.setControl('led1', value);
                      await DatabaseService.setControl('led2', value);
                      await DatabaseService.setControl('led3', value);
                      await DatabaseService.setControl('motor', value);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // First Row - Door and Living Room Light
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.door_front_door, size: 40, color: Colors.orange),
                              const SizedBox(height: 8),
                              const Text('Cửa thông minh', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Huge Austdoor', style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isDoorOn,
                                    onChanged: (bool value) async {
                                      await DatabaseService.setControl('servo_angle', value ? '90' : '0');
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.grey[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb, size: 40, color: Colors.yellow),
                              const SizedBox(height: 8),
                              const Text('Đèn phòng khách', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Zumtobel', style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isLivingLightOn,
                                    onChanged: (bool value) async {
                                      await DatabaseService.setControl('led1', value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Second Row - Bedroom and Bathroom Lights
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.grey[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb, size: 40, color: Colors.yellow),
                              const SizedBox(height: 8),
                              const Text('Đèn phòng ngủ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Zumtobel', style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isBedroomLightOn,
                                    onChanged: (bool value) async {
                                      await DatabaseService.setControl('led2', value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.grey[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb, size: 40, color: Colors.yellow),
                              const SizedBox(height: 8),
                              const Text('Đèn phòng bếp', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Zumtobel', style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isBathroomLightOn,
                                    onChanged: (bool value) async {
                                      await DatabaseService.setControl('led3', value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Third Row - Fan
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.cyan[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.ac_unit, size: 40, color: Colors.cyan),
                              const SizedBox(height: 8),
                              const Text('Quạt thông minh', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Làm mát', style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isFanOn,
                                    onChanged: (bool value) async {
                                      await DatabaseService.setControl('motor', value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),

      // Floating voice button
      floatingActionButton: GestureDetector(
        onLongPressStart: (_) => _startListening(),
        onLongPressEnd: (_) => _stopListening(),
        child: FloatingActionButton(
          onPressed: () {
            if (_voiceService.isRecording) {
              _stopListening();
            } else {
              _startListening();
            }
          },
          shape: const CircleBorder(),
          backgroundColor: _voiceService.isRecording ? Colors.redAccent : Colors.teal,
          foregroundColor: Colors.white,
          child: Icon(
            _voiceService.isRecording ? Icons.mic_off : Icons.mic,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom navigation
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            const Icon(Icons.home, color: Colors.teal),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.grey),
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}