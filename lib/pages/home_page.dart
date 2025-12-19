import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../utils/helpers.dart';
import '../services/firebase_service.dart';
import '../services/voice_service.dart';
import 'notifications_page.dart';
import 'camera_stream_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Device states
  bool isDoorOn = false;
  bool isLivingLightOn = false;
  bool isBedroomLightOn = false;
  bool isKitchenLightOn = false;
  bool isFanOn = false;
  bool isCameraOn = false;

  // Sensors
  double? temperature;
  double? humidity;
  int? mq2Value;
  bool _mq2WarningSent = false;
  Timer? _mq2Timer;

  // Voice recognition
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;
  String _lastWords = '';

  // Notifications list
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupListeners();
  }

  @override
  void dispose() {
    _mq2Timer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _voiceService.initializeSpeech();
    await _voiceService.loadModel();
  }

  void _setupListeners() {
    // Listen to device controls
    FirebaseService.listenToDeviceControl('led1').listen((event) {
      if (mounted) {
        setState(() {
          isLivingLightOn = Helpers.toBool(event.snapshot.value);
        });
      }
    });

    FirebaseService.listenToDeviceControl('led2').listen((event) {
      if (mounted) {
        setState(() {
          isBedroomLightOn = Helpers.toBool(event.snapshot.value);
        });
      }
    });

    FirebaseService.listenToDeviceControl('led3').listen((event) {
      if (mounted) {
        setState(() {
          isKitchenLightOn = Helpers.toBool(event.snapshot.value);
        });
      }
    });

    FirebaseService.listenToDeviceControl('motor').listen((event) {
      if (mounted) {
        setState(() {
          isFanOn = Helpers.toBool(event.snapshot.value);
        });
      }
    });

    FirebaseService.listenToDeviceControl('servo_angle').listen((event) {
      if (mounted) {
        setState(() {
          isDoorOn = (event.snapshot.value != "0");
        });
      }
    });

    // Listen to sensors
    FirebaseService.listenToSensors().listen((event) {
      if (mounted) {
        final data = event.snapshot.value;
        if (data is Map) {
          setState(() {
            temperature =
                Helpers.toDouble(Helpers.extract(data, ['temperature']));
            humidity = Helpers.toDouble(Helpers.extract(data, ['humidity']));
          });

          _checkTemperatureAlert(temperature);
        }
      }
    });

    // Listen to notifications
    FirebaseService.listenToNotifications().listen((event) {
      if (mounted) {
        final data = event.snapshot.value;
        if (data is Map) {
          _processNotifications(data);
        }
      }
    });

    // Listen to camera status
    FirebaseService.listenToCamera().listen((event) {
      if (mounted) {
        final data = event.snapshot.value;
        if (data is Map) {
          setState(() {
            isCameraOn = Helpers.toBool(data['status']);
          });
        }
      }
    });

    // Listen to MQ2 sensor
    FirebaseDatabase.instance.ref('mq2').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && mounted) {
        setState(() {
          mq2Value = int.tryParse(data.toString()) ?? 0;
        });
        _checkMQ2Alert(mq2Value!);
      }
    });
  }

  void _processNotifications(Map data) {
    _notifications.clear();
    int unreadCount = 0;

    data.forEach((key, value) {
      if (value is Map) {
        final notification = {
          'id': key,
          'message': value['message'] ?? '',
          'type': value['type'] ?? 'info',
          'timestamp': value['timestamp'],
          'read': value['read'] ?? false,
          'action': value['action'] ?? '',
          'time': value['time'] ?? '',
          'date': value['date'] ?? '',
          'fullDateTime': value['fullDateTime'] ?? '',
          'user': value['user'] ?? '',
          'userEmail': value['userEmail'] ?? '',
          'sensor': value['sensor'] ?? '',
          'value': value['value'] ?? '',
        };
        _notifications.insert(0, notification);
        if (!(value['read'] ?? false)) {
          unreadCount++;
        }
      }
    });

    if (mounted) {
      setState(() {
        _unreadNotifications = unreadCount;
        if (_notifications.length > 50) _notifications.removeLast();
      });
    }
  }

  void _checkTemperatureAlert(double? temp) {
    if (temp != null && temp > 30) {
      _addNotification(
        '🚨 High temperature: ${temp.toStringAsFixed(1)}°C. Please turn on fan or AC.',
        'temperature_alert',
      );
    }
  }

  void _checkMQ2Alert(int mq2Value) {
    if (mq2Value == 0 && !_mq2WarningSent) {
      _addGasAlertNotification();
      _mq2WarningSent = true;

      _mq2Timer?.cancel();

      _mq2Timer = Timer(const Duration(minutes: 5), () {
        if (mounted) {
          setState(() {
            _mq2WarningSent = false;
          });
        }
      });
    } else if (mq2Value > 0) {
      _mq2WarningSent = false;
      _mq2Timer?.cancel();
    }
  }

  Future<void> _addGasAlertNotification() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String currentTime = Helpers.formatTime(DateTime.now());
      final String currentDate = Helpers.formatDate(DateTime.now());

      await FirebaseService.addNotification({
        'message': '🚨 DANGER',
        'type': 'gas_alert',
        'timestamp': ServerValue.timestamp,
        'read': false,
        'time': currentTime,
        'date': currentDate,
        'fullDateTime': '$currentTime - $currentDate',
        'user': user.displayName ?? 'User',
        'userId': user.uid,
        'userEmail': user.email,
        'sensor': 'MQ2',
        'value': 0,
        'priority': 'high',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '🚨 DANGER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: _navigateToNotifications,
            ),
          ),
        );
      }
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _addNotification(String message, String type) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String currentTime = Helpers.formatTime(DateTime.now());
      final String currentDate = Helpers.formatDate(DateTime.now());

      await FirebaseService.addNotification({
        'message': message,
        'type': type,
        'timestamp': ServerValue.timestamp,
        'read': false,
        'time': currentTime,
        'date': currentDate,
        'fullDateTime': '$currentTime - $currentDate',
        'user': user.displayName ?? 'User',
        'userId': user.uid,
        'userEmail': user.email,
      });
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _addDoorNotification(String action, String command) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String currentTime = Helpers.formatTime(DateTime.now());
      final String currentDate = Helpers.formatDate(DateTime.now());

      await FirebaseService.addNotification({
        'message': 'Door $action by voice - "$command"',
        'type': 'door_voice',
        'timestamp': ServerValue.timestamp,
        'read': false,
        'action': action,
        'time': currentTime,
        'date': currentDate,
        'fullDateTime': '$currentTime - $currentDate',
        'user': user.displayName ?? 'User',
        'userId': user.uid,
        'userEmail': user.email,
      });
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _setControl(String key, dynamic value) async {
    try {
      await FirebaseService.setDeviceControl(
        key,
        value is bool ? (value ? 'ON' : 'OFF') : value,
      );

      // บันทึกสถิติเมื่อมีการใช้งานอุปกรณ์
      await _recordDeviceUsage(key, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update failed')),
        );
      }
    }
  }

  Future<void> _recordDeviceUsage(String deviceId, dynamic value) async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final timeKey = DateFormat('HH:mm:ss').format(now);
      final user = FirebaseAuth.instance.currentUser;

      final ref = FirebaseDatabase.instance.ref();

      // 1. บันทึกสถิติแบบนับจำนวนครั้ง
      await ref
          .child('statistics/$dateKey/$deviceId')
          .set(ServerValue.increment(1));

      // 2. บันทึกรายละเอียดการใช้งาน (optional)
      await ref.child('usage_logs/$dateKey/${now.millisecondsSinceEpoch}').set({
        'device': deviceId,
        'time': timeKey,
        'timestamp': now.toIso8601String(),
        'user': user?.uid ?? 'unknown',
        'userEmail': user?.email ?? '',
        'action': value is bool ? (value ? 'ON' : 'OFF') : value.toString(),
        'status': value is bool
            ? value
            : (value.toString() == 'ON' ||
                value.toString() == '1' ||
                value.toString() == '90'),
      });

      // 3. บันทึกสรุปประจำวัน
      await _updateDailySummary(dateKey, deviceId);

      print('📊 Recorded usage for $deviceId on $dateKey');
    } catch (e) {
      print('Error recording device usage: $e');
    }
  }

  Future<void> _updateDailySummary(String dateKey, String deviceId) async {
    try {
      final ref = FirebaseDatabase.instance.ref();
      final user = FirebaseAuth.instance.currentUser;

      // ดึงข้อมูลสถิติปัจจุบัน
      final snapshot = await ref.child('daily_summary/$dateKey').get();
      Map<String, dynamic> summaryData = {};

      if (snapshot.exists) {
        summaryData = Map<String, dynamic>.from(snapshot.value as Map);
      }

      // อัปเดตข้อมูลอุปกรณ์
      if (!summaryData.containsKey('devices')) {
        summaryData['devices'] = {};
      }

      final devices = Map<String, dynamic>.from(summaryData['devices'] as Map);
      devices[deviceId] = (devices[deviceId] ?? 0) + 1;
      summaryData['devices'] = devices;

      // อัปเดตจำนวนการใช้งานทั้งหมด
      summaryData['total_usage'] = (summaryData['total_usage'] ?? 0) + 1;

      // อัปเดตเวลาล่าสุด
      summaryData['last_updated'] = ServerValue.timestamp;
      summaryData['last_user'] = user?.uid ?? 'unknown';

      // บันทึกข้อมูล
      await ref.child('daily_summary/$dateKey').set(summaryData);
    } catch (e) {
      print('Error updating daily summary: $e');
    }
  }

  void _startListening() {
    if (!_voiceService.isSpeechEnabled) return;

    setState(() {
      _isListening = true;
      _lastWords =
          _voiceService.isModelLoaded ? 'AI is listening...' : 'Listening...';
    });

    _voiceService.startListening(
      (command) => _onSpeechResult(command),
      (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
    );
  }

  void _stopListening() async {
    await _voiceService.stopListening();
    setState(() => _isListening = false);
  }

  void _onSpeechResult(String command) {
    setState(() {
      _lastWords = command;
    });

    _processVoiceCommand(command);
  }

  Future<void> _processVoiceCommand(String command) async {
    final lowerCommand = command.toLowerCase();
    String feedback = 'Command not understood';
    bool isDoorCommand = false;
    String action = '';

    final aiCommand = _voiceService.classifyCommand(command);
    if (aiCommand != null) {
      await _executeAICommand(aiCommand.key, command);
      return;
    }

    if (lowerCommand.contains('bật quạt') || lowerCommand.contains('mở quạt')) {
      await _voiceService.playSound('switch_on');
      await _setControl('motor', true);
      feedback = 'Fan turned on';
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt')) {
      await _voiceService.playSound('switch_off');
      await _setControl('motor', false);
      feedback = 'Fan turned off';
    } else if (lowerCommand.contains('bật tất cả đèn') ||
        lowerCommand.contains('mở tất cả đèn') ||
        lowerCommand.contains('bật tất cả') ||
        lowerCommand.contains('mở tất cả')) {
      await _voiceService.playSound('switch_on');
      await _setControl('led1', true);
      await _setControl('led2', true);
      await _setControl('led3', true);
      await _setControl('motor', true);
      feedback = 'All lights and fan turned on';
    } else if (lowerCommand.contains('tắt tất cả đèn') ||
        lowerCommand.contains('đóng tất cả đèn') ||
        lowerCommand.contains('tắt tất cả') ||
        lowerCommand.contains('đóng tất cả')) {
      await _voiceService.playSound('switch_off');
      await _setControl('led1', false);
      await _setControl('led2', false);
      await _setControl('led3', false);
      await _setControl('motor', false);
      feedback = 'All lights and fan turned off';
    } else if (lowerCommand.contains('bật đèn phòng khách') ||
        lowerCommand.contains('mở đèn phòng khách')) {
      await _voiceService.playSound('switch_on');
      await _setControl('led1', true);
      feedback = 'Living room light turned on';
    } else if (lowerCommand.contains('tắt đèn phòng khách') ||
        lowerCommand.contains('đóng đèn phòng khách')) {
      await _voiceService.playSound('switch_off');
      await _setControl('led1', false);
      feedback = 'Living room light turned off';
    } else if (lowerCommand.contains('bật đèn phòng ngủ') ||
        lowerCommand.contains('mở đèn phòng ngủ')) {
      await _voiceService.playSound('switch_on');
      await _setControl('led2', true);
      feedback = 'Bedroom light turned on';
    } else if (lowerCommand.contains('tắt đèn phòng ngủ') ||
        lowerCommand.contains('đóng đèn phòng ngủ')) {
      await _voiceService.playSound('switch_off');
      await _setControl('led2', false);
      feedback = 'Bedroom light turned off';
    } else if (lowerCommand.contains('bật đèn phòng bếp') ||
        lowerCommand.contains('mở đèn phòng bếp') ||
        lowerCommand.contains('bật đèn bếp') ||
        lowerCommand.contains('mở đèn bếp')) {
      await _voiceService.playSound('switch_on');
      await _setControl('led3', true);
      feedback = 'Kitchen light turned on';
    } else if (lowerCommand.contains('tắt đèn phòng bếp') ||
        lowerCommand.contains('đóng đèn phòng bếp') ||
        lowerCommand.contains('tắt đèn bếp') ||
        lowerCommand.contains('đóng đèn bếp')) {
      await _voiceService.playSound('switch_off');
      await _setControl('led3', false);
      feedback = 'Kitchen light turned off';
    } else if (lowerCommand.contains('mở cửa') ||
        lowerCommand.contains('mở khóa cửa')) {
      await _voiceService.playSound('switch_on');
      await _setControl('servo_angle', '90');
      feedback = 'Door opened';
      isDoorCommand = true;
      action = 'opened';
    } else if (lowerCommand.contains('đóng cửa') ||
        lowerCommand.contains('khóa cửa')) {
      await _voiceService.playSound('switch_off');
      await _setControl('servo_angle', '0');
      feedback = 'Door closed';
      isDoorCommand = true;
      action = 'closed';
    }

    if (isDoorCommand) {
      await _addDoorNotification(action, command);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedback), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _executeAICommand(
      String commandLabel, String originalCommand) async {
    String feedback = 'Command executed';
    bool isDoorCommand = false;
    String action = '';

    switch (commandLabel) {
      case 'bat_quat':
        await _voiceService.playSound('switch_on');
        await _setControl('motor', true);
        feedback = 'Fan turned on (AI)';
        break;
      case 'tat_quat':
        await _voiceService.playSound('switch_off');
        await _setControl('motor', false);
        feedback = 'Fan turned off (AI)';
        break;
      case 'bat_tat_ca':
        await _voiceService.playSound('switch_on');
        await _setControl('led1', true);
        await _setControl('led2', true);
        await _setControl('led3', true);
        await _setControl('motor', true);
        feedback = 'All devices turned on (AI)';
        break;
      case 'tat_tat_ca':
        await _voiceService.playSound('switch_off');
        await _setControl('led1', false);
        await _setControl('led2', false);
        await _setControl('led3', false);
        await _setControl('motor', false);
        feedback = 'All devices turned off (AI)';
        break;
      case 'bat_den_phong_khach':
        await _voiceService.playSound('switch_on');
        await _setControl('led1', true);
        feedback = 'Living room light turned on (AI)';
        break;
      case 'tat_den_phong_khach':
        await _voiceService.playSound('switch_off');
        await _setControl('led1', false);
        feedback = 'Living room light turned off (AI)';
        break;
      case 'bat_den_phong_ngu':
        await _voiceService.playSound('switch_on');
        await _setControl('led2', true);
        feedback = 'Bedroom light turned on (AI)';
        break;
      case 'tat_den_phong_ngu':
        await _voiceService.playSound('switch_off');
        await _setControl('led2', false);
        feedback = 'Bedroom light turned off (AI)';
        break;
      case 'bat_den_phong_bep':
        await _voiceService.playSound('switch_on');
        await _setControl('led3', true);
        feedback = 'Kitchen light turned on (AI)';
        break;
      case 'tat_den_phong_bep':
        await _voiceService.playSound('switch_off');
        await _setControl('led3', false);
        feedback = 'Kitchen light turned off (AI)';
        break;
      default:
        await _processVoiceCommand(originalCommand);
        return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.yellow[700]),
              const SizedBox(width: 8),
              Text(feedback),
            ],
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _startCamera() async {
    try {
      await FirebaseService.updateCameraStatus(true);
      await _voiceService.playSound('camera_start');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CameraStreamPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera startup error')),
        );
      }
    }
  }

  Future<void> _stopCamera() async {
    try {
      await FirebaseService.updateCameraStatus(false);
    } catch (e) {
      // Silent error
    }
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsPage(notifications: _notifications),
      ),
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
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseService.signOut();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  String getGreeting() {
    return Helpers.getGreeting();
  }

  String getFormattedDate() {
    final now = DateTime.now();
    final months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getGreeting(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Smart Home',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.videocam),
                      onPressed: _startCamera,
                      tooltip: 'Camera',
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: _navigateToNotifications,
                          tooltip: 'Notifications',
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
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                _unreadNotifications > 9
                                    ? '9+'
                                    : _unreadNotifications.toString(),
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
                      tooltip: 'Settings',
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
                    const Text(
                      'In Da Nang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      getFormattedDate(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Temperature and Humidity Card
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
                          const Text('Temperature'),
                          Text(
                            temperature != null
                                ? '${temperature!.toStringAsFixed(0)}°'
                                : '--',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(Helpers.getTemperatureLabel(temperature)),
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
                          const Text('Humidity'),
                          Text(
                            humidity != null
                                ? '${humidity!.toStringAsFixed(0)}%'
                                : '--',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(Helpers.getHumidityLabel(humidity)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Device List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Camera Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Security Camera',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Live', style: TextStyle(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.videocam,
                      size: 40,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      'Security Camera',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Home monitoring'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('View live'),
                      onPressed: _startCamera,
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
                      'Smart Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Refresh', style: TextStyle(color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),

                // Main switch for all devices
                Card(
                  child: SwitchListTile(
                    title: const Text('All devices'),
                    value: isDoorOn &&
                        isLivingLightOn &&
                        isBedroomLightOn &&
                        isKitchenLightOn &&
                        isFanOn,
                    onChanged: (bool value) async {
                      await _voiceService
                          .playSound(value ? 'switch_on' : 'switch_off');
                      _setControl('servo_angle', value ? '90' : '0');
                      _setControl('led1', value);
                      _setControl('led2', value);
                      _setControl('led3', value);
                      _setControl('motor', value);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // First row - Door and Living room light
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
                              const Icon(
                                Icons.door_front_door,
                                size: 40,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Smart door',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Huge Austdoor',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isDoorOn,
                                    onChanged: (bool value) async {
                                      await _voiceService.playSound(
                                          value ? 'switch_on' : 'switch_off');
                                      _setControl(
                                          'servo_angle', value ? '90' : '0');
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
                              const Icon(
                                Icons.lightbulb,
                                size: 40,
                                color: Colors.yellow,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Living room light',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Zumtobel',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isLivingLightOn,
                                    onChanged: (bool value) async {
                                      await _voiceService.playSound(
                                          value ? 'switch_on' : 'switch_off');
                                      _setControl('led1', value);
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

                // Second row - Bedroom and Kitchen lights
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
                              const Icon(
                                Icons.lightbulb,
                                size: 40,
                                color: Colors.yellow,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bedroom light',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Zumtobel',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isBedroomLightOn,
                                    onChanged: (bool value) async {
                                      await _voiceService.playSound(
                                          value ? 'switch_on' : 'switch_off');
                                      _setControl('led2', value);
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
                              const Icon(
                                Icons.lightbulb,
                                size: 40,
                                color: Colors.yellow,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Kitchen light',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Zumtobel',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isKitchenLightOn,
                                    onChanged: (bool value) async {
                                      await _voiceService.playSound(
                                          value ? 'switch_on' : 'switch_off');
                                      _setControl('led3', value);
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

                // Third row - Fan
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
                              const Icon(
                                Icons.ac_unit,
                                size: 40,
                                color: Colors.cyan,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Smart fan',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Cooling',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isFanOn,
                                    onChanged: (bool value) async {
                                      await _voiceService.playSound(
                                          value ? 'switch_on' : 'switch_off');
                                      _setControl('motor', value);
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

      // Floating voice control button
      floatingActionButton: GestureDetector(
        onLongPressStart: (_) => _startListening(),
        onLongPressEnd: (_) => _stopListening(),
        child: FloatingActionButton(
          onPressed: () {
            if (_isListening) {
              _stopListening();
            } else {
              _startListening();
            }
          },
          shape: const CircleBorder(),
          backgroundColor: _isListening
              ? Colors.redAccent
              : (_voiceService.isModelLoaded ? Colors.amber : Colors.teal),
          foregroundColor: Colors.white,
          child: Icon(
            _isListening
                ? Icons.mic_off
                : (_voiceService.isModelLoaded
                    ? Icons.auto_awesome
                    : Icons.mic),
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom navigation bar
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
}
