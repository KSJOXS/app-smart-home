// main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'firebase_options.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // เริ่มต้นกล้อง
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Camera Error: $e');
  }

  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// APP ROOT
// -----------------------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cardStyle = CardThemeData(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return MaterialApp(
      title: 'Smart Home Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.teal),
        cardTheme: cardStyle,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOGIN PAGE
// -----------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '';
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      await _createUserProfile(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    final DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/${user.uid}');
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set({
        'name': user.displayName ?? 'User',
        'email': user.email,
        'phone': '',
        'address': '',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00BFA6), Color(0xFF00695C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home, size: 72, color: Colors.teal),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart Home Pro',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter your email'
                          : null,
                      onChanged: (v) => email = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter your password'
                          : null,
                      onChanged: (v) => password = v.trim(),
                    ),
                    const SizedBox(height: 20),
                    _loading
                        ? const CircularProgressIndicator(color: Colors.teal)
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Don't have an account? Register",
                        style: TextStyle(color: Colors.teal),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REGISTER PAGE - Simplified with only Full Name
// -----------------------------------------------------------------------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '', name = '';
  bool _loading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // Create user with email and password
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update display name
      await userCredential.user!
          .updateDisplayName(name.isEmpty ? 'User' : name);

      // Create user profile in database
      await _createUserProfile(userCredential.user!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    final DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/${user.uid}');
    await userRef.set({
      'name': name.isEmpty ? 'User' : name,
      'email': user.email,
      'phone': '',
      'address': '',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 20, color: Colors.teal),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your name' : null,
                    onChanged: (v) => name = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your email' : null,
                    onChanged: (v) => email = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6
                        ? 'Minimum 6 characters'
                        : null,
                    onChanged: (v) => password = v.trim(),
                  ),
                  const SizedBox(height: 16),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 22,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Register',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HOME PAGE - Enhanced Voice Control for Raspberry Pi
// -----------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _controlRef =
      FirebaseDatabase.instance.ref('control');
  final DatabaseReference _sensorsRef = FirebaseDatabase.instance.ref();
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('notifications');
  final DatabaseReference _cameraRef = FirebaseDatabase.instance.ref('camera');

  // Device states
  bool isDoorOn = false;
  bool isLivingLightOn = false;
  bool isBedroomLightOn = false;
  bool isBathroomLightOn = false;
  bool isFanOn = false;
  bool isCameraOn = false;

  // Sensors
  double? temperature;
  double? humidity;

  // Voice recognition
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  // Audio player for button sounds
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Notifications list
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _listenControl();
    _listenSensors();
    _listenNotifications();
    _listenCamera();
    _speechToText = stt.SpeechToText();
    _initSpeech();
  }

  /// Play sound effect
  Future<void> _playSound(String soundType) async {
    try {
      if (soundType == 'switch_on') {
        await _audioPlayer.play(AssetSource('sounds/switch_on.mp3'));
      } else if (soundType == 'switch_off') {
        await _audioPlayer.play(AssetSource('sounds/switch_off.mp3'));
      } else if (soundType == 'voice_start') {
        await _audioPlayer.play(AssetSource('sounds/voice_start.mp3'));
      } else if (soundType == 'voice_stop') {
        await _audioPlayer.play(AssetSource('sounds/voice_stop.mp3'));
      } else if (soundType == 'camera_start') {
        await _audioPlayer.play(AssetSource('sounds/camera_start.mp3'));
      }
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Initialises speech recognition services
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
    if (!_speechEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available.')),
      );
    }
  }

  /// Start listening to voice input
  void _startListening() async {
    if (!_speechEnabled) return;
    await _playSound('voice_start');
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'en_US',
    );
    setState(() {
      _isListening = true;
      _lastWords = 'Listening...';
    });
  }

  /// Stop listening to voice input
  void _stopListening() async {
    await _speechToText.stop();
    await _playSound('voice_stop');
    setState(() => _isListening = false);
  }

  /// This is called when the user stops talking
  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _processVoiceCommand(_lastWords);
    });
  }

  /// Enhanced Voice Command Processing for Raspberry Pi
  Future<void> _processVoiceCommand(String command) async {
    debugPrint('Voice Command: "$command"');

    final lowerCommand = command.toLowerCase();
    String feedback = 'Command not understood';

    // Enhanced voice commands for better recognition
    if (lowerCommand.contains('open door') ||
        lowerCommand.contains('unlock door')) {
      await _setControl('servo_angle', '90');
      await _playSound('switch_on');
      feedback = 'Door opened';
    } else if (lowerCommand.contains('close door') ||
        lowerCommand.contains('lock door')) {
      await _setControl('servo_angle', '0');
      await _playSound('switch_off');
      feedback = 'Door closed';
    } else if (lowerCommand.contains('turn on living room light') ||
        lowerCommand.contains('living room light on') ||
        lowerCommand.contains('light on living room') ||
        lowerCommand.contains('living room on')) {
      await _setControl('led1', true);
      await _playSound('switch_on');
      feedback = 'Living room light turned on';
    } else if (lowerCommand.contains('turn off living room light') ||
        lowerCommand.contains('living room light off') ||
        lowerCommand.contains('light off living room') ||
        lowerCommand.contains('living room off')) {
      await _setControl('led1', false);
      await _playSound('switch_off');
      feedback = 'Living room light turned off';
    } else if (lowerCommand.contains('turn on bedroom light') ||
        lowerCommand.contains('bedroom light on') ||
        lowerCommand.contains('light on bedroom') ||
        lowerCommand.contains('bedroom on')) {
      await _setControl('led2', true);
      await _playSound('switch_on');
      feedback = 'Bedroom light turned on';
    } else if (lowerCommand.contains('turn off bedroom light') ||
        lowerCommand.contains('bedroom light off') ||
        lowerCommand.contains('light off bedroom') ||
        lowerCommand.contains('bedroom off')) {
      await _setControl('led2', false);
      await _playSound('switch_off');
      feedback = 'Bedroom light turned off';
    } else if (lowerCommand.contains('turn on bathroom light') ||
        lowerCommand.contains('bathroom light on') ||
        lowerCommand.contains('light on bathroom') ||
        lowerCommand.contains('bathroom on')) {
      await _setControl('led3', true);
      await _playSound('switch_on');
      feedback = 'Bathroom light turned on';
    } else if (lowerCommand.contains('turn off bathroom light') ||
        lowerCommand.contains('bathroom light off') ||
        lowerCommand.contains('light off bathroom') ||
        lowerCommand.contains('bathroom off')) {
      await _setControl('led3', false);
      await _playSound('switch_off');
      feedback = 'Bathroom light turned off';
    } else if (lowerCommand.contains('turn on fan') ||
        lowerCommand.contains('fan on') ||
        lowerCommand.contains('start fan')) {
      await _setControl('motor', true);
      await _playSound('switch_on');
      feedback = 'Fan turned on';
    } else if (lowerCommand.contains('turn off fan') ||
        lowerCommand.contains('fan off') ||
        lowerCommand.contains('stop fan')) {
      await _setControl('motor', false);
      await _playSound('switch_off');
      feedback = 'Fan turned off';
    } else if (lowerCommand.contains('all lights on') ||
        lowerCommand.contains('turn on all lights') ||
        lowerCommand.contains('lights on')) {
      await _setControl('led1', true);
      await _setControl('led2', true);
      await _setControl('led3', true);
      await _playSound('switch_on');
      feedback = 'All lights turned on';
    } else if (lowerCommand.contains('all lights off') ||
        lowerCommand.contains('turn off all lights') ||
        lowerCommand.contains('lights off')) {
      await _setControl('led1', false);
      await _setControl('led2', false);
      await _setControl('led3', false);
      await _playSound('switch_off');
      feedback = 'All lights turned off';
    } else if (lowerCommand.contains('open camera') ||
        lowerCommand.contains('start camera') ||
        lowerCommand.contains('show camera') ||
        lowerCommand.contains('camera on')) {
      await _startCamera();
      feedback = 'Opening camera';
    } else if (lowerCommand.contains('close camera') ||
        lowerCommand.contains('stop camera') ||
        lowerCommand.contains('hide camera') ||
        lowerCommand.contains('camera off')) {
      await _stopCamera();
      feedback = 'Closing camera';
    } else if (lowerCommand.contains('status') ||
        lowerCommand.contains('what is the status')) {
      feedback =
          'Temperature: ${temperature?.toStringAsFixed(1) ?? "--"}°C, Humidity: ${humidity?.toStringAsFixed(1) ?? "--"}%';
    }

    // Add notification for voice command
    await _addNotification('Voice Command: $command', 'voice');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Add notification to Firebase
  Future<void> _addNotification(String message, String type) async {
    try {
      final String notificationId =
          DateTime.now().millisecondsSinceEpoch.toString();
      await _notificationsRef.child(notificationId).set({
        'message': message,
        'type': type,
        'timestamp': ServerValue.timestamp,
        'read': false,
      });
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  // Check temperature alert
  void _checkTemperatureAlert(double? temp) {
    if (temp != null && temp > 30) {
      _addNotification(
          '🚨 High Temperature: ${temp.toStringAsFixed(1)}°C. Consider turning on the fan or air conditioner.',
          'temperature_alert');
    }
  }

  Future<void> _setControl(String key, dynamic value) async {
    try {
      // Send command to Firebase - Raspberry Pi will listen to this
      await _controlRef
          .child(key)
          .set(value is bool ? (value ? 'ON' : 'OFF') : value);
      debugPrint('Control command sent: $key = $value');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  // Camera control methods
  Future<void> _startCamera() async {
    try {
      await _cameraRef.set({
        'status': 'on',
        'timestamp': ServerValue.timestamp,
      });
      await _playSound('camera_start');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CameraStreamPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start camera: $e')),
        );
      }
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _cameraRef.set({
        'status': 'off',
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
  }

  void _listenControl() {
    _controlRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          isLivingLightOn = _toBool(data['led1']);
          isBedroomLightOn = _toBool(data['led2']);
          isBathroomLightOn = _toBool(data['led3']);
          isFanOn = _toBool(data['motor']);
          final angle = data['servo_angle'];
          isDoorOn = (angle != "0");
        });
      }
    });
  }

  void _listenCamera() {
    _cameraRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          isCameraOn = _toBool(data['status']);
        });
      }
    });
  }

  void _listenSensors() {
    _sensorsRef.onValue.listen((event) {
      final snapshotVal = event.snapshot.value;
      if (snapshotVal is Map && mounted) {
        setState(() {
          temperature =
              _toDouble(_extract(snapshotVal, ['sensors', 'temperature'])) ??
                  _toDouble(snapshotVal['temperature']);
          humidity =
              _toDouble(_extract(snapshotVal, ['sensors', 'humidity'])) ??
                  _toDouble(snapshotVal['humidity']);
        });

        // Call temperature alert check
        _checkTemperatureAlert(temperature);
      }
    });
  }

  void _listenNotifications() {
    _notificationsRef.limitToLast(50).onValue.listen((event) {
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

  // Navigate to notifications page
  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              NotificationsPage(notifications: _notifications)),
    );
  }

  // Helpers to convert different formats from database
  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'on' || s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // Nested extract helper
  dynamic _extract(Map m, List<String> path) {
    dynamic cur = m;
    for (final p in path) {
      if (cur is Map && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  // Show logout confirmation dialog
  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // Navigate to settings page
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  // Navigate to camera page
  void _navigateToCamera() {
    _startCamera();
  }

  // Get greeting based on time
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  // Get formatted date
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
      'December'
    ];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
  }

  // Get temp label
  String getTempLabel(double? temp) {
    if (temp == null) return '';
    if (temp > 25) return 'Warm';
    if (temp > 20) return 'Comfortable';
    return 'Cool';
  }

  // Get humidity label
  String getHumidityLabel(double? hum) {
    if (hum == null) return '';
    if (hum > 60) return 'High';
    if (hum > 40) return 'Normal';
    return 'Low';
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
                    Text(getGreeting(),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Smart Home',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                          const Text('Temperature'),
                          Text(
                            temperature != null
                                ? '${temperature!.toStringAsFixed(0)}°'
                                : '--',
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold),
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
                          const Text('Humidity'),
                          Text(
                            humidity != null
                                ? '${humidity!.toStringAsFixed(0)}%'
                                : '--',
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold),
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

          // Devices List
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Live', style: TextStyle(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.videocam,
                        size: 40, color: Colors.blue),
                    title: const Text('Security Camera',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Home monitoring'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('View Live'),
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
                      'Smart Devices',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Refresh', style: TextStyle(color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),

                // Master Switch for All Devices
                Card(
                  child: SwitchListTile(
                    title: const Text('All Devices'),
                    value: isDoorOn &&
                        isLivingLightOn &&
                        isBedroomLightOn &&
                        isBathroomLightOn &&
                        isFanOn,
                    onChanged: (value) async {
                      await _playSound(value ? 'switch_on' : 'switch_off');
                      _setControl('servo_angle', value ? '90' : '0');
                      _setControl('led1', value);
                      _setControl('led2', value);
                      _setControl('led3', value);
                      _setControl('motor', value);
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
                              const Icon(Icons.door_front_door,
                                  size: 40, color: Colors.orange),
                              const SizedBox(height: 8),
                              const Text('Smart Door',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Huge Austdoor',
                                  style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isDoorOn,
                                    onChanged: (value) async {
                                      await _playSound(
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
                              const Icon(Icons.lightbulb,
                                  size: 40, color: Colors.yellow),
                              const SizedBox(height: 8),
                              const Text('Living Room Light',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Zumtobel',
                                  style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isLivingLightOn,
                                    onChanged: (value) async {
                                      await _playSound(
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
                              const Icon(Icons.lightbulb,
                                  size: 40, color: Colors.yellow),
                              const SizedBox(height: 8),
                              const Text('Bedroom Light',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Zumtobel',
                                  style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isBedroomLightOn,
                                    onChanged: (value) async {
                                      await _playSound(
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
                              const Icon(Icons.lightbulb,
                                  size: 40, color: Colors.yellow),
                              const SizedBox(height: 8),
                              const Text('Bathroom Light',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Zumtobel',
                                  style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isBathroomLightOn,
                                    onChanged: (value) async {
                                      await _playSound(
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
                              const Icon(Icons.ac_unit,
                                  size: 40, color: Colors.cyan),
                              const SizedBox(height: 8),
                              const Text('Smart Fan',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Cooling',
                                  style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isFanOn,
                                    onChanged: (value) async {
                                      await _playSound(
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

      // Voice Control Floating Action Button
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
          backgroundColor: _isListening ? Colors.redAccent : Colors.teal,
          foregroundColor: Colors.white,
          child: Icon(_isListening ? Icons.mic_off : Icons.mic, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Navigation Bar
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

// -----------------------------------------------------------------------------
// NOTIFICATIONS PAGE
// -----------------------------------------------------------------------------
class NotificationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;

  const NotificationsPage({super.key, required this.notifications});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('notifications');

  @override
  Widget build(BuildContext context) {
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
      body: widget.notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Notifications will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: widget.notifications.length,
              itemBuilder: (context, index) {
                final notification = widget.notifications[index];
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
                  key: Key(notification['id'] ?? index.toString()),
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
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${timeFormat.format(dateTime)} • ${dateFormat.format(dateTime)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
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
                      },
                      onLongPress: () {
                        _showNotificationDetails(notification);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).update({
        'read': true,
      });
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
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This action cannot be undone.'),
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
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
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
        title: const Text('Notification Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Message: $message'),
            const SizedBox(height: 8),
            Text('Type: $type'),
            const SizedBox(height: 8),
            Text('Time: ${timeFormat.format(dateTime)}'),
            Text('Date: ${dateFormat.format(dateTime)}'),
            const SizedBox(height: 8),
            Text('Status: ${isRead ? 'Read' : 'Unread'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CAMERA STREAM PAGE
// -----------------------------------------------------------------------------
class CameraStreamPage extends StatefulWidget {
  const CameraStreamPage({super.key});

  @override
  State<CameraStreamPage> createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends State<CameraStreamPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  url: ${error.url}
            ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://192.168.1.16:5000'));
  }

  Future<void> _refreshStream() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Camera'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStream,
            tooltip: 'Refresh Stream',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Status
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Security Camera',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Camera Stream
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Connecting to camera...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_hasError)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to connect to camera',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Connection'),
                            onPressed: _refreshStream,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SETTINGS PAGE
// -----------------------------------------------------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedLanguage = 'English';

  // Face Registration Function with Real Camera
  Future<void> _registerFace() async {
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not available')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceRegistrationCameraPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref('users/${user?.uid}').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final userData = snapshot.data?.snapshot.value as Map?;
          final userName = userData?['name'] ?? 'User';
          final userEmail = userData?['email'] ?? user?.email ?? 'No email';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Section
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(userName),
                  subtitle: Text(userEmail),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Security Section with Face Registration
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Security',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.face, color: Colors.purple),
                      title: const Text('Face Registration'),
                      subtitle:
                          const Text('Register your face for smart access'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _registerFace,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // App Settings Section
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'App Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Receive push notifications'),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Enable dark theme'),
                      value: _darkMode,
                      onChanged: (value) {
                        setState(() {
                          _darkMode = value;
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('Language'),
                      subtitle: Text(_selectedLanguage),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showLanguageDialog();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () {
                    _showLogoutDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Thai'),
              leading: Radio<String>(
                value: 'Thai',
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FACE REGISTRATION CAMERA PAGE - AUTO CAPTURE 60 IMAGES
// -----------------------------------------------------------------------------
class FaceRegistrationCameraPage extends StatefulWidget {
  @override
  _FaceRegistrationCameraPageState createState() =>
      _FaceRegistrationCameraPageState();
}

class _FaceRegistrationCameraPageState
    extends State<FaceRegistrationCameraPage> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  int _currentImageCount = 0;
  final int _targetImageCount = 60;
  Timer? _captureTimer;

  // เก็บรูปภาพเป็น Base64
  List<String> _base64Images = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not available')),
        );
      }
      return;
    }

    final CameraDescription camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
      });
    }).catchError((Object e) {
      if (e is CameraException) {
        _showError('Camera error: ${e.description}');
      }
    });
  }

  // แปลงรูปภาพเป็น Base64
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      return base64Image;
    } catch (e) {
      print('Error converting image: $e');
      rethrow;
    }
  }

  // เริ่มถ่ายภาพต่อเนื่อง
  Future<void> _startContinuousCapture() async {
    if (!_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _currentImageCount = 0;
      _base64Images.clear();
    });

    // แจ้งผู้ใช้ให้ขยับใบหน้า
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Starting continuous capture - Please move your head slowly in different angles'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    // เริ่มถ่ายภาพทุก 0.5 วินาที
    _captureTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_currentImageCount >= _targetImageCount) {
        _stopContinuousCapture();
        return;
      }

      await _captureSingleImage();
    });
  }

  // หยุดถ่ายภาพต่อเนื่อง
  void _stopContinuousCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;

    setState(() {
      _isCapturing = false;
    });

    // แจ้งผู้ใช้เมื่อถ่ายภาพครบ
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture completed! $_currentImageCount images saved'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // บันทึกข้อมูลเมื่อถ่ายภาพครบ
    if (_currentImageCount >= _targetImageCount) {
      _completeRegistration();
    }
  }

  // ถ่ายภาพเดียว
  Future<void> _captureSingleImage() async {
    if (!_isCameraReady ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // ถ่ายรูป
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);

      // แปลงรูปภาพเป็น Base64
      final String base64Image = await _convertImageToBase64(imageFile);

      // เก็บ Base64 image
      _base64Images.add(base64Image);

      // อัพเดทจำนวนภาพ
      setState(() {
        _currentImageCount = _base64Images.length;
        _isProcessing = false;
      });

      print('Image $_currentImageCount captured and converted to Base64');

      // ลบไฟล์ชั่วคราว
      await imageFile.delete();
    } catch (e) {
      debugPrint('Error capturing image: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeRegistration() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not logged in');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // บันทึกข้อมูลลง Firebase Database
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/${user.uid}');

      // สร้าง structure สำหรับเก็บรูปภาพ
      Map<String, dynamic> faceImagesData = {};

      for (int i = 0; i < _base64Images.length; i++) {
        faceImagesData['image_$i'] = {
          'base64': _base64Images[i],
          'timestamp': DateTime.now().millisecondsSinceEpoch + i,
          'size': _base64Images[i].length,
          'angle': _getAngleDescription(i),
        };
      }

      await userRef.update({
        'faceRegistered': true,
        'faceRegistrationDate': ServerValue.timestamp,
        'faceImages': faceImagesData,
        'totalFaceImages': _base64Images.length,
        'targetImages': _targetImageCount,
        'lastFaceUpdate': ServerValue.timestamp,
        'registrationComplete': true,
        'registrationMethod': 'continuous_capture',
      });

      setState(() {
        _isProcessing = false;
      });

      // แจ้งผลสำเร็จ
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Registration Successful'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Face registration completed successfully!'),
                  const SizedBox(height: 16),
                  Text(
                    '$_currentImageCount images saved to database.',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total data size: ${_calculateTotalSize()} KB',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your face is now registered for smart access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // ปิด dialog
                    Navigator.pop(context); // กลับไปหน้า settings
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to complete registration: $e');
    }
  }

  // คำอธิบายมุมการถ่ายภาพ
  String _getAngleDescription(int index) {
    if (index < 20) return 'front';
    if (index < 40) return 'left_side';
    return 'right_side';
  }

  String _calculateTotalSize() {
    int totalBytes = 0;
    for (var image in _base64Images) {
      totalBytes += image.length;
    }
    return (totalBytes / 1024).toStringAsFixed(2);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Registration'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_base64Images.isNotEmpty) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          LinearProgressIndicator(
            value: _currentImageCount / _targetImageCount,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Image $_currentImageCount of $_targetImageCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    '${((_currentImageCount / _targetImageCount) * 100).round()}%'),
                _isCapturing
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RECORDING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const Text('Ready'),
              ],
            ),
          ),

          // Camera Preview
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (_controller != null &&
                          _controller!.value.isInitialized) {
                        return CameraPreview(_controller!);
                      } else {
                        return _buildCameraError();
                      }
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                ),

                // Face Guide Circle
                Container(
                  width: 250,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isCapturing ? Colors.red : Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 60,
                        color: _isCapturing
                            ? Colors.red
                            : Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Position Face Here',
                        style: TextStyle(
                          color: _isCapturing ? Colors.red : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Instructions
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isCapturing
                              ? 'Capturing... Move your head slowly\n$_currentImageCount/$_targetImageCount images'
                              : 'Position your face in the frame\nThen start continuous capture',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        if (!_isCapturing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'We will automatically capture 60 images from different angles',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Processing Indicator
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing image...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control Buttons
          Expanded(
            flex: 1,
            child: Center(
              child: _isProcessing && !_isCapturing
                  ? _buildProcessingIndicator()
                  : _buildControlButtons(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Camera not available'),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _initializeCamera,
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Saving to database...',
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isCapturing)
          FloatingActionButton.large(
            onPressed: _isCameraReady ? _startContinuousCapture : null,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Icon(Icons.play_arrow, size: 36),
          )
        else
          FloatingActionButton.large(
            onPressed: _stopContinuousCapture,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Icon(Icons.stop, size: 36),
          ),
        const SizedBox(height: 16),
        Text(
          _isCapturing
              ? 'Tap to stop capture'
              : 'Tap to start continuous capture',
          style: const TextStyle(fontSize: 16),
        ),
        if (_base64Images.isNotEmpty && !_isCapturing) ...[
          const SizedBox(height: 8),
          Text(
            '$_currentImageCount images ready',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Registration?'),
        content: Text(
            'You have $_currentImageCount images captured. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE PAGE - Simplified without Username
// -----------------------------------------------------------------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late DatabaseReference _userRef;
  bool _editing = false;
  bool _loading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    _userRef = FirebaseDatabase.instance.ref('users/${user?.uid}');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    try {
      final snapshot = await _userRef.get();
      if (snapshot.exists) {
        final userData = snapshot.value as Map;
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _addressController.text = userData['address'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _userRef.update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'updatedAt': ServerValue.timestamp,
      });

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: Icon(_editing ? Icons.save : Icons.edit),
              onPressed: () {
                setState(() {
                  if (_editing) {
                    _saveProfile();
                  } else {
                    _editing = true;
                  }
                });
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder(
              stream: _userRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final userData = snapshot.data?.snapshot.value as Map?;
                final currentName = userData?['name'] ?? 'User';
                final currentEmail =
                    userData?['email'] ?? user?.email ?? 'No email';

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.teal,
                              child: Text(
                                currentName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 36, color: Colors.white),
                              ),
                            ),
                            if (_editing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.teal,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email),
                                  border: const OutlineInputBorder(),
                                  hintText: currentEmail,
                                ),
                                enabled: false,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                  prefixIcon: Icon(Icons.home),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              if (!_editing)
                                Column(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        _showChangePasswordDialog();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32, vertical: 12),
                                      ),
                                      child: const Text('Change Password'),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Security Settings'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  hintText: 'Enter current password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Enter new password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  hintText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully')),
              );
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
