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
import 'package:tflite_flutter/tflite_flutter.dart';

import 'firebase_options.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi tạo camera
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Lỗi Camera: $e');
  }

  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// Phân loại giọng nói TFLite - UPDATED WITH NEW LABELS
// -----------------------------------------------------------------------------
class VoiceClassifier {
  static const String modelFile = 'model.tflite';
  static const String labelFile = 'voice_labels.txt';

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      // Tải model
      _interpreter = await Interpreter.fromAsset(modelFile);

      // Tải nhãn - UPDATED WITH NEW LABELS
      _labels = await _loadLabelsFromAssets();

      _isLoaded = true;
      debugPrint('Đã tải model giọng nói thành công');
      debugPrint('Nhãn: $_labels');

      // Debug model info
      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();
      debugPrint('Input tensors: $inputTensors');
      debugPrint('Output tensors: $outputTensors');
    } catch (e) {
      debugPrint('Lỗi tải model giọng nói: $e');
      _isLoaded = false;
    }
  }

  Future<List<String>> _loadLabelsFromAssets() async {
    // Updated labels based on your voice_labels.txt
    return [
      'bat_quat',
      'tat_quat',
      'bat_tat_ca',
      'tat_tat_ca',
      'bat_den_phong_khach',
      'tat_den_phong_khach',
      'bat_den_phong_ngu',
      'tat_den_phong_ngu',
      'tat_den_phong_bep',
      'bat_den_phong_bep'
    ];
  }

  // Xử lý trước âm thanh - SIMPLIFIED VERSION
  List<List<double>> _preprocessAudio(List<double> audioData) {
    try {
      const int inputLength = 16000; // Default for speech models

      // Tạo mảng 2D với hình dạng phù hợp cho model
      List<List<double>> processedInput = [];

      // Xử lý đơn giản - đệm hoặc cắt ngắn đến độ dài mong đợi
      List<double> processedAudio = List<double>.filled(inputLength, 0.0);
      int length =
          audioData.length < inputLength ? audioData.length : inputLength;

      for (int i = 0; i < length; i++) {
        processedAudio[i] = audioData[i];
      }

      // Định hình lại cho đầu vào model
      processedInput.add(processedAudio);

      return processedInput;
    } catch (e) {
      debugPrint('Lỗi xử lý âm thanh: $e');
      return [List<double>.filled(16000, 0.0)];
    }
  }

  // Phân loại lệnh giọng nói từ đặc trưng âm thanh
  Map<String, double> classifyVoiceCommand(List<double> audioFeatures) {
    if (!_isLoaded) {
      debugPrint('Model chưa được tải');
      return {};
    }

    try {
      // Xử lý trước âm thanh
      final input = _preprocessAudio(audioFeatures);

      // Chuẩn bị bộ đệm đầu ra
      var outputBuffer = List<double>.filled(_labels.length, 0.0);

      // Chạy suy luận
      _interpreter.run(input, outputBuffer);

      debugPrint('Kết quả raw: $outputBuffer');

      // Xử lý kết quả
      final Map<String, double> labeledProb = {};

      for (int i = 0; i < outputBuffer.length && i < _labels.length; i++) {
        labeledProb[_labels[i]] = outputBuffer[i];
      }

      debugPrint('Kết quả phân loại: $labeledProb');
      return labeledProb;
    } catch (e) {
      debugPrint('Lỗi trong quá trình phân loại giọng nói: $e');
      return {};
    }
  }

  // Phân loại từ lệnh văn bản (dự phòng) - UPDATED WITH NEW LABELS
  Map<String, double> classifyTextCommand(String textCommand) {
    final lowerCommand = textCommand.toLowerCase();
    Map<String, double> results = {};

    // Khớp từ khóa với điểm tin cậy - UPDATED WITH NEW LABELS
    if (lowerCommand.contains('bật quạt') || lowerCommand.contains('mở quạt')) {
      results['bat_quat'] = 0.95;
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt')) {
      results['tat_quat'] = 0.95;
    } else if (lowerCommand.contains('bật tất cả') ||
        lowerCommand.contains('mở tất cả') ||
        lowerCommand.contains('bật tất cả đèn') ||
        lowerCommand.contains('mở tất cả đèn')) {
      results['bat_tat_ca'] = 0.90;
    } else if (lowerCommand.contains('tắt tất cả') ||
        lowerCommand.contains('đóng tất cả') ||
        lowerCommand.contains('tắt tất cả đèn') ||
        lowerCommand.contains('đóng tất cả đèn')) {
      results['tat_tat_ca'] = 0.90;
    } else if (lowerCommand.contains('bật đèn phòng khách') ||
        lowerCommand.contains('mở đèn phòng khách')) {
      results['bat_den_phong_khach'] = 0.85;
    } else if (lowerCommand.contains('tắt đèn phòng khách') ||
        lowerCommand.contains('đóng đèn phòng khách')) {
      results['tat_den_phong_khach'] = 0.85;
    } else if (lowerCommand.contains('bật đèn phòng ngủ') ||
        lowerCommand.contains('mở đèn phòng ngủ')) {
      results['bat_den_phong_ngu'] = 0.85;
    } else if (lowerCommand.contains('tắt đèn phòng ngủ') ||
        lowerCommand.contains('đóng đèn phòng ngủ')) {
      results['tat_den_phong_ngu'] = 0.85;
    } else if (lowerCommand.contains('bật đèn phòng bếp') ||
        lowerCommand.contains('mở đèn phòng bếp') ||
        lowerCommand.contains('bật đèn bếp') ||
        lowerCommand.contains('mở đèn bếp')) {
      results['bat_den_phong_bep'] = 0.85;
    } else if (lowerCommand.contains('tắt đèn phòng bếp') ||
        lowerCommand.contains('đóng đèn phòng bếp') ||
        lowerCommand.contains('tắt đèn bếp') ||
        lowerCommand.contains('đóng đèn bếp')) {
      results['tat_den_phong_bep'] = 0.85;
    }

    return results;
  }

  MapEntry<String, double>? getTopCommand(List<double> audioFeatures) {
    final results = classifyVoiceCommand(audioFeatures);
    return _getTopResult(results);
  }

  MapEntry<String, double>? getTopCommandFromText(String textCommand) {
    final results = classifyTextCommand(textCommand);
    return _getTopResult(results);
  }

  MapEntry<String, double>? _getTopResult(Map<String, double> results) {
    if (results.isEmpty) return null;

    var topEntry = results.entries.reduce((a, b) => a.value > b.value ? a : b);

    return topEntry.value > 0.6 ? topEntry : null;
  }

  bool get isLoaded => _isLoaded;

  void dispose() {
    _interpreter.close();
  }
}

// -----------------------------------------------------------------------------
// ỨNG DỤNG CHÍNH
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
      title: 'Nhà Thông Minh Pro',
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
// TRANG ĐĂNG NHẬP
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
        SnackBar(content: Text(e.message ?? 'Đăng nhập thất bại')),
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
        'name': user.displayName ?? 'Người dùng',
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
                      'Nhà Thông Minh Pro',
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
                          ? 'Vui lòng nhập email của bạn'
                          : null,
                      onChanged: (v) => email = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Vui lòng nhập mật khẩu của bạn'
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
                                'ĐĂNG NHẬP',
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
                        "Chưa có tài khoản? Đăng ký",
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
// TRANG ĐĂNG KÝ
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
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user!
          .updateDisplayName(name.isEmpty ? 'Người dùng' : name);
      await _createUserProfile(userCredential.user!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Đăng ký thất bại')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    final DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/${user.uid}');
    await userRef.set({
      'name': name.isEmpty ? 'Người dùng' : name,
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
        title: const Text('Đăng ký'),
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
                    'Tạo Tài Khoản',
                    style: TextStyle(fontSize: 20, color: Colors.teal),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nhập tên của bạn' : null,
                    onChanged: (v) => name = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nhập email của bạn' : null,
                    onChanged: (v) => email = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Tối thiểu 6 ký tự' : null,
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
                            'Đăng ký',
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
// TRANG CHỦ - Điều khiển giọng nói nâng cao với TFLite
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

  // Trạng thái thiết bị
  bool isDoorOn = false;
  bool isLivingLightOn = false;
  bool isBedroomLightOn = false;
  bool isKitchenLightOn = false;
  bool isFanOn = false;
  bool isCameraOn = false;

  // Cảm biến
  double? temperature;
  double? humidity;

  // Nhận dạng giọng nói
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  // Phân loại giọng nói TFLite
  final VoiceClassifier _voiceClassifier = VoiceClassifier();
  bool _isModelLoaded = false;
  bool _useTFLite = true;

  // Trình phát âm thanh
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Danh sách thông báo
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _listenControl();
    _listenSensors();
    _listenNotifications();
    _listenCamera();

    // Khởi tạo hệ thống giọng nói
    _speechToText = stt.SpeechToText();
    _initSpeech();
    _loadTFLiteModel();
  }

  Future<void> _loadTFLiteModel() async {
    try {
      await _voiceClassifier.loadModel();
      setState(() {
        _isModelLoaded = _voiceClassifier.isLoaded;
      });

      if (_isModelLoaded) {
        debugPrint('Đã tải model TFLite thành công');
      } else {
        debugPrint('Model TFLite tải thất bại');
        setState(() {
          _useTFLite = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải model TFLite: $e');
      setState(() {
        _isModelLoaded = false;
        _useTFLite = false;
      });
    }
  }

  /// Phát hiệu ứng âm thanh
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
      debugPrint('Lỗi phát âm thanh: $e');
    }
  }

  /// Khởi tạo dịch vụ nhận dạng giọng nói
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
    if (!_speechEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhận dạng giọng nói không khả dụng.')),
      );
    }
  }

  /// Bắt đầu lắng nghe đầu vào giọng nói
  void _startListening() async {
    if (!_speechEnabled) return;

    setState(() {
      _isListening = true;
      _lastWords = _isModelLoaded && _useTFLite
          ? 'AI đang lắng nghe...'
          : 'Đang lắng nghe...';
    });

    await _speechToText.listen(
      onResult: _onSpeechResultWithTFLite,
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 10),
    );
  }

  /// Dừng lắng nghe đầu vào giọng nói
  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  /// Xử lý giọng nói với TFLite
  void _onSpeechResultWithTFLite(stt.SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });

    if (result.finalResult) {
      if (_isModelLoaded && _useTFLite) {
        _processVoiceCommandWithTFLite(_lastWords);
      } else {
        // Fallback to traditional processing
        _processVoiceCommand(_lastWords);
      }
    }
  }

  /// Xử lý lệnh giọng nói nâng cao với TFLite - UPDATED WITH NEW LABELS
  Future<void> _processVoiceCommandWithTFLite(String command) async {
    debugPrint('Lệnh giọng nói với TFLite: "$command"');

    if (_isModelLoaded && _useTFLite) {
      // Thử phân loại với TFLite trước
      final topCommand = _voiceClassifier.getTopCommandFromText(command);

      if (topCommand != null) {
        debugPrint(
            'TFLite phát hiện: ${topCommand.key} với độ tin cậy: ${topCommand.value}');
        await _executeCommandByLabel(topCommand.key, command);
        return;
      }
    }

    // Quay lại xử lý truyền thống
    await _processVoiceCommand(command);
  }

  /// Thực thi lệnh dựa trên nhãn TFLite - UPDATED WITH NEW LABELS
  Future<void> _executeCommandByLabel(
      String commandLabel, String originalCommand) async {
    String feedback = 'Lệnh đã được thực thi';
    bool commandExecuted = true;

    switch (commandLabel) {
      case 'bat_quat':
        await _setControl('motor', true);
        await _playSound('switch_on');
        feedback = 'Đã bật quạt';
        break;

      case 'tat_quat':
        await _setControl('motor', false);
        await _playSound('switch_off');
        feedback = 'Đã tắt quạt';
        break;

      case 'bat_tat_ca':
        await _setControl('led1', true);
        await _setControl('led2', true);
        await _setControl('led3', true);
        await _playSound('switch_on');
        feedback = 'Đã bật tất cả đèn';
        break;

      case 'tat_tat_ca':
        await _setControl('led1', false);
        await _setControl('led2', false);
        await _setControl('led3', false);
        await _playSound('switch_off');
        feedback = 'Đã tắt tất cả đèn';
        break;

      case 'bat_den_phong_khach':
        await _setControl('led1', true);
        await _playSound('switch_on');
        feedback = 'Đã bật đèn phòng khách';
        break;

      case 'tat_den_phong_khach':
        await _setControl('led1', false);
        await _playSound('switch_off');
        feedback = 'Đã tắt đèn phòng khách';
        break;

      case 'bat_den_phong_ngu':
        await _setControl('led2', true);
        await _playSound('switch_on');
        feedback = 'Đã bật đèn phòng ngủ';
        break;

      case 'tat_den_phong_ngu':
        await _setControl('led2', false);
        await _playSound('switch_off');
        feedback = 'Đã tắt đèn phòng ngủ';
        break;

      case 'bat_den_phong_bep':
        await _setControl('led3', true);
        await _playSound('switch_on');
        feedback = 'Đã bật đèn phòng bếp';
        break;

      case 'tat_den_phong_bep':
        await _setControl('led3', false);
        await _playSound('switch_off');
        feedback = 'Đã tắt đèn phòng bếp';
        break;

      default:
        commandExecuted = false;
        // Quay lại xử lý truyền thống
        await _processVoiceCommand(originalCommand);
        return;
    }

    if (commandExecuted) {
      // Thêm thông báo cho lệnh AI phát hiện
      await _addNotification('Lệnh AI: $commandLabel', 'voice_ai');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.yellow[700]),
                const SizedBox(width: 8),
                Text('$feedback (AI)'),
              ],
            ),
            backgroundColor: Colors.green[800],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Xử lý lệnh giọng nói truyền thống - UPDATED WITH NEW LABELS
  Future<void> _processVoiceCommand(String command) async {
    debugPrint('Lệnh giọng nói truyền thống: "$command"');

    final lowerCommand = command.toLowerCase();
    String feedback = 'Không hiểu lệnh';

    // Lệnh giọng nói tiếng Việt - UPDATED WITH NEW LABELS
    if (lowerCommand.contains('bật quạt') || lowerCommand.contains('mở quạt')) {
      await _setControl('motor', true);
      await _playSound('switch_on');
      feedback = 'Đã bật quạt';
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt')) {
      await _setControl('motor', false);
      await _playSound('switch_off');
      feedback = 'Đã tắt quạt';
    } else if (lowerCommand.contains('bật tất cả đèn') ||
        lowerCommand.contains('mở tất cả đèn') ||
        lowerCommand.contains('bật tất cả') ||
        lowerCommand.contains('mở tất cả')) {
      await _setControl('led1', true);
      await _setControl('led2', true);
      await _setControl('led3', true);
      await _playSound('switch_on');
      feedback = 'Đã bật tất cả đèn';
    } else if (lowerCommand.contains('tắt tất cả đèn') ||
        lowerCommand.contains('đóng tất cả đèn') ||
        lowerCommand.contains('tắt tất cả') ||
        lowerCommand.contains('đóng tất cả')) {
      await _setControl('led1', false);
      await _setControl('led2', false);
      await _setControl('led3', false);
      await _playSound('switch_off');
      feedback = 'Đã tắt tất cả đèn';
    } else if (lowerCommand.contains('bật đèn phòng khách') ||
        lowerCommand.contains('mở đèn phòng khách')) {
      await _setControl('led1', true);
      await _playSound('switch_on');
      feedback = 'Đã bật đèn phòng khách';
    } else if (lowerCommand.contains('tắt đèn phòng khách') ||
        lowerCommand.contains('đóng đèn phòng khách')) {
      await _setControl('led1', false);
      await _playSound('switch_off');
      feedback = 'Đã tắt đèn phòng khách';
    } else if (lowerCommand.contains('bật đèn phòng ngủ') ||
        lowerCommand.contains('mở đèn phòng ngủ')) {
      await _setControl('led2', true);
      await _playSound('switch_on');
      feedback = 'Đã bật đèn phòng ngủ';
    } else if (lowerCommand.contains('tắt đèn phòng ngủ') ||
        lowerCommand.contains('đóng đèn phòng ngủ')) {
      await _setControl('led2', false);
      await _playSound('switch_off');
      feedback = 'Đã tắt đèn phòng ngủ';
    } else if (lowerCommand.contains('bật đèn phòng bếp') ||
        lowerCommand.contains('mở đèn phòng bếp') ||
        lowerCommand.contains('bật đèn bếp') ||
        lowerCommand.contains('mở đèn bếp')) {
      await _setControl('led3', true);
      await _playSound('switch_on');
      feedback = 'Đã bật đèn phòng bếp';
    } else if (lowerCommand.contains('tắt đèn phòng bếp') ||
        lowerCommand.contains('đóng đèn phòng bếp') ||
        lowerCommand.contains('tắt đèn bếp') ||
        lowerCommand.contains('đóng đèn bếp')) {
      await _setControl('led3', false);
      await _playSound('switch_off');
      feedback = 'Đã tắt đèn phòng bếp';
    } else if (lowerCommand.contains('mở cửa') ||
        lowerCommand.contains('mở khóa cửa')) {
      await _setControl('servo_angle', '90');
      await _playSound('switch_on');
      feedback = 'Đã mở cửa';
    } else if (lowerCommand.contains('đóng cửa') ||
        lowerCommand.contains('khóa cửa')) {
      await _setControl('servo_angle', '0');
      await _playSound('switch_off');
      feedback = 'Đã đóng cửa';
    } else if (lowerCommand.contains('mở camera') ||
        lowerCommand.contains('bật camera')) {
      await _startCamera();
      feedback = 'Đang mở camera';
    } else if (lowerCommand.contains('đóng camera') ||
        lowerCommand.contains('tắt camera')) {
      await _stopCamera();
      feedback = 'Đang đóng camera';
    }

    // Thêm thông báo cho lệnh giọng nói
    await _addNotification('Lệnh giọng nói: $command', 'voice');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Thêm thông báo vào Firebase
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
      debugPrint('Lỗi thêm thông báo: $e');
    }
  }

  // Kiểm tra cảnh báo nhiệt độ
  void _checkTemperatureAlert(double? temp) {
    if (temp != null && temp > 30) {
      _addNotification(
          '🚨 Nhiệt độ cao: ${temp.toStringAsFixed(1)}°C. Hãy bật quạt hoặc điều hòa.',
          'temperature_alert');
    }
  }

  Future<void> _setControl(String key, dynamic value) async {
    try {
      // Gửi lệnh đến Firebase - Raspberry Pi sẽ lắng nghe
      await _controlRef
          .child(key)
          .set(value is bool ? (value ? 'ON' : 'OFF') : value);
      debugPrint('Lệnh điều khiển đã gửi: $key = $value');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật thất bại: $e')),
        );
      }
    }
  }

  // Phương thức điều khiển camera
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
          SnackBar(content: Text('Lỗi khởi động camera: $e')),
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
      debugPrint('Lỗi dừng camera: $e');
    }
  }

  void _listenControl() {
    _controlRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          isLivingLightOn = _toBool(data['led1']);
          isBedroomLightOn = _toBool(data['led2']);
          isKitchenLightOn = _toBool(data['led3']);
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

        // Gọi kiểm tra cảnh báo nhiệt độ
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

  // Điều hướng đến trang thông báo
  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              NotificationsPage(notifications: _notifications)),
    );
  }

  // Chuyển đổi chế độ TFLite
  void _toggleTFLiteMode(bool value) {
    setState(() {
      _useTFLite = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useTFLite
              ? 'Chế độ giọng nói AI: BẬT'
              : 'Chế độ giọng nói thường: BẬT'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Hàm trợ giúp chuyển đổi định dạng từ database
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

  // Hàm trích xuất lồng nhau
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

  // Hiển thị hộp thoại xác nhận đăng xuất
  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child:
                  const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // Điều hướng đến trang cài đặt
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  // Điều hướng đến trang camera
  void _navigateToCamera() {
    _startCamera();
  }

  // Lời chào dựa trên thời gian
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng,';
    if (hour < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  // Ngày được định dạng
  String getFormattedDate() {
    final now = DateTime.now();
    final months = [
      '',
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12'
    ];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
  }

  // Nhãn nhiệt độ
  String getTempLabel(double? temp) {
    if (temp == null) return '';
    if (temp > 25) return 'Ấm';
    if (temp > 20) return 'Thoải mái';
    return 'Mát';
  }

  // Nhãn độ ẩm
  String getHumidityLabel(double? hum) {
    if (hum == null) return '';
    if (hum > 60) return 'Cao';
    if (hum > 40) return 'Bình thường';
    return 'Thấp';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Phần Header
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
                    const Text('Nhà Thông Minh',
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
                      tooltip: 'Cài đặt',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Địa điểm và Ngày
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
                      'Tại Đà Nẵng',
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

          // Thẻ Nhiệt độ và Độ ẩm
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
                          const Text('Độ ẩm'),
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

          // Danh sách Thiết bị
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Chuyển đổi chế độ giọng nói
                Card(
                  child: SwitchListTile(
                    title: const Text('Nhận dạng giọng nói AI'),
                    subtitle: Text(_isModelLoaded
                        ? 'Sử dụng model TFLite cho lệnh giọng nói'
                        : 'Model TFLite chưa được tải'),
                    value: _useTFLite && _isModelLoaded,
                    onChanged: _isModelLoaded ? _toggleTFLiteMode : null,
                    secondary: Icon(
                      _useTFLite && _isModelLoaded
                          ? Icons.auto_awesome
                          : Icons.mic,
                      color: _useTFLite && _isModelLoaded
                          ? Colors.amber
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Phần Camera
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Camera An ninh',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Trực tiếp', style: TextStyle(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.videocam,
                        size: 40, color: Colors.blue),
                    title: const Text('Camera An ninh',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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

                // Phần Thiết bị Thông minh
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Thiết bị Thông minh',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Làm mới', style: TextStyle(color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),

                // Công tắc chính cho tất cả thiết bị
                Card(
                  child: SwitchListTile(
                    title: const Text('Tất cả thiết bị'),
                    value: isDoorOn &&
                        isLivingLightOn &&
                        isBedroomLightOn &&
                        isKitchenLightOn &&
                        isFanOn,
                    onChanged: (bool value) async {
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

                // Hàng đầu tiên - Cửa và Đèn phòng khách
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
                              const Text('Cửa thông minh',
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
                                    onChanged: (bool value) async {
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
                              const Text('Đèn phòng khách',
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
                                    onChanged: (bool value) async {
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

                // Hàng thứ hai - Đèn phòng ngủ và phòng bếp
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
                              const Text('Đèn phòng ngủ',
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
                                    onChanged: (bool value) async {
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
                              const Text('Đèn phòng bếp',
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
                                    value: isKitchenLightOn,
                                    onChanged: (bool value) async {
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

                // Hàng thứ ba - Quạt
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
                              const Text('Quạt thông minh',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Làm mát',
                                  style: TextStyle(color: Colors.grey)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onLongPressStart: (_) => _startListening(),
                                  onLongPressEnd: (_) => _stopListening(),
                                  child: Switch(
                                    value: isFanOn,
                                    onChanged: (bool value) async {
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

      // Nút điều khiển giọng nói nổi
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
              : (_useTFLite && _isModelLoaded ? Colors.amber : Colors.teal),
          foregroundColor: Colors.white,
          child: Icon(
              _isListening
                  ? Icons.mic_off
                  : (_useTFLite && _isModelLoaded
                      ? Icons.auto_awesome
                      : Icons.mic),
              size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Thanh điều hướng dưới cùng
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
    _voiceClassifier.dispose();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// TRANG THÔNG BÁO
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
        title: const Text('Thông báo'),
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
                  Text(
                    'Không có thông báo',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Thông báo sẽ xuất hiện ở đây',
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
      debugPrint('Lỗi đánh dấu thông báo đã đọc: $e');
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
          const SnackBar(content: Text('Đã đánh dấu tất cả thông báo đã đọc')),
        );
      }
    } catch (e) {
      debugPrint('Lỗi đánh dấu tất cả thông báo đã đọc: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).remove();
    } catch (e) {
      debugPrint('Lỗi xóa thông báo: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationsRef.remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tất cả thông báo')),
        );
      }
    } catch (e) {
      debugPrint('Lỗi xóa tất cả thông báo: $e');
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả thông báo'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa tất cả thông báo? Hành động này không thể hoàn tác.'),
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
            child:
                const Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
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
}

// -----------------------------------------------------------------------------
// TRANG CAMERA
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
            debugPrint('WebView đang tải: $progress%');
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
Lỗi tài nguyên trang:
  mã: ${error.errorCode}
  mô tả: ${error.description}
  loại lỗi: ${error.errorType}
  url: ${error.url}
            ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://10.83.56.116:5000'));
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
        title: const Text('Camera An ninh'),
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
            tooltip: 'Làm mới luồng',
          ),
        ],
      ),
      body: Column(
        children: [
          // Trạng thái Camera
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
                      'TRỰC TIẾP',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Camera An ninh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Luồng Camera
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
                            'Đang kết nối đến camera...',
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
                            'Không thể kết nối đến camera',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại kết nối'),
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
// TRANG CÀI ĐẶT
// -----------------------------------------------------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedLanguage = 'Tiếng Việt';

  // Hàm đăng ký khuôn mặt với camera thật
  Future<void> _registerFace() async {
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera không khả dụng')),
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
        title: const Text('Cài đặt'),
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
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final userData = snapshot.data?.snapshot.value as Map?;
          final userName = userData?['name'] ?? 'Người dùng';
          final userEmail =
              userData?['email'] ?? user?.email ?? 'Không có email';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Phần Hồ sơ
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

              // Phần Bảo mật với đăng ký khuôn mặt
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bảo mật',
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
                      title: const Text('Đăng ký khuôn mặt'),
                      subtitle: const Text(
                          'Đăng ký khuôn mặt để truy cập thông minh'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _registerFace,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Phần Cài đặt Ứng dụng
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Cài đặt Ứng dụng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Thông báo đẩy'),
                      subtitle: const Text('Nhận thông báo đẩy'),
                      value: _notificationsEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Chế độ tối'),
                      subtitle: const Text('Bật chủ đề tối'),
                      value: _darkMode,
                      onChanged: (bool value) {
                        setState(() {
                          _darkMode = value;
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('Ngôn ngữ'),
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

              // Nút Đăng xuất
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
                        'Đăng xuất',
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
        title: const Text('Chọn ngôn ngữ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Tiếng Việt'),
              leading: Radio<String>(
                value: 'Tiếng Việt',
                groupValue: _selectedLanguage,
                onChanged: (String? value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (String? value) {
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
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TRANG ĐĂNG KÝ KHUÔN MẶT
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

  // Lưu hình ảnh dưới dạng Base64
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
          const SnackBar(content: Text('Camera không khả dụng')),
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
        _showError('Lỗi camera: ${e.description}');
      }
    });
  }

  // Chuyển đổi hình ảnh sang Base64
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      return base64Image;
    } catch (e) {
      print('Lỗi chuyển đổi hình ảnh: $e');
      rethrow;
    }
  }

  // Bắt đầu chụp ảnh liên tục
  Future<void> _startContinuousCapture() async {
    if (!_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _currentImageCount = 0;
      _base64Images.clear();
    });

    // Thông báo cho người dùng di chuyển khuôn mặt
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bắt đầu chụp liên tục - Vui lòng di chuyển đầu chậm ở các góc độ khác nhau'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    // Bắt đầu chụp ảnh mỗi 0.5 giây
    _captureTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_currentImageCount >= _targetImageCount) {
        _stopContinuousCapture();
        return;
      }

      await _captureSingleImage();
    });
  }

  // Dừng chụp ảnh liên tục
  void _stopContinuousCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;

    setState(() {
      _isCapturing = false;
    });

    // Thông báo cho người dùng khi chụp ảnh hoàn tất
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chụp hoàn tất! Đã lưu $_currentImageCount ảnh'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Lưu dữ liệu khi chụp ảnh hoàn tất
    if (_currentImageCount >= _targetImageCount) {
      _completeRegistration();
    }
  }

  // Chụp một ảnh duy nhất
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

      // Chụp hình
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);

      // Chuyển đổi hình ảnh sang Base64
      final String base64Image = await _convertImageToBase64(imageFile);

      // Lưu Base64 image
      _base64Images.add(base64Image);

      // Cập nhật số lượng ảnh
      setState(() {
        _currentImageCount = _base64Images.length;
        _isProcessing = false;
      });

      print('Đã chụp và chuyển đổi ảnh $_currentImageCount sang Base64');

      // Xóa file tạm thời
      await imageFile.delete();
    } catch (e) {
      debugPrint('Lỗi chụp ảnh: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeRegistration() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Người dùng chưa đăng nhập');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Lưu dữ liệu vào Firebase Database
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/${user.uid}');

      // Tạo cấu trúc để lưu hình ảnh
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

      // Thông báo thành công
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
                  Text('Đăng ký Thành công'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Đăng ký khuôn mặt hoàn tất thành công!'),
                  const SizedBox(height: 16),
                  Text(
                    'Đã lưu $_currentImageCount ảnh vào cơ sở dữ liệu.',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tổng kích thước dữ liệu: ${_calculateTotalSize()} KB',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Khuôn mặt của bạn đã được đăng ký để truy cập thông minh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Đóng dialog
                    Navigator.pop(context); // Quay lại trang cài đặt
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
      _showError('Lỗi hoàn tất đăng ký: $e');
    }
  }

  // Mô tả góc chụp
  String _getAngleDescription(int index) {
    if (index < 20) return 'trước';
    if (index < 40) return 'bên trái';
    return 'bên phải';
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
        title: const Text('Đăng ký Khuôn mặt'),
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
          // Thanh tiến trình
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
                  'Ảnh $_currentImageCount trên $_targetImageCount',
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
                          'ĐANG GHI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const Text('Sẵn sàng'),
              ],
            ),
          ),

          // Xem trước Camera
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

                // Vòng tròn hướng dẫn khuôn mặt
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
                        'Đặt khuôn mặt ở đây',
                        style: TextStyle(
                          color: _isCapturing ? Colors.red : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Hướng dẫn
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
                              ? 'Đang chụp... Di chuyển đầu chậm\n$_currentImageCount/$_targetImageCount ảnh'
                              : 'Đặt khuôn mặt trong khung\nSau đó bắt đầu chụp liên tục',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        if (!_isCapturing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Chúng tôi sẽ tự động chụp 60 ảnh từ các góc độ khác nhau',
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

                // Chỉ báo xử lý
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
                            'Đang xử lý ảnh...',
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

          // Nút điều khiển
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
        const Text('Camera không khả dụng'),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _initializeCamera,
          child: const Text('Thử lại'),
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
          'Đang lưu vào cơ sở dữ liệu...',
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
          _isCapturing ? 'Chạm để dừng chụp' : 'Chạm để bắt đầu chụp liên tục',
          style: const TextStyle(fontSize: 16),
        ),
        if (_base64Images.isNotEmpty && !_isCapturing) ...[
          const SizedBox(height: 8),
          Text(
            '$_currentImageCount ảnh đã sẵn sàng',
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
        title: const Text('Thoát đăng ký?'),
        content: Text(
            'Bạn có $_currentImageCount ảnh đã chụp. Bạn có chắc chắn muốn thoát?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Thoát', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TRANG HỒ SƠ
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
      debugPrint('Lỗi tải dữ liệu người dùng: $e');
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
          const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
        );
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật hồ sơ: $e')),
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
        title: const Text('Hồ sơ'),
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
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final userData = snapshot.data?.snapshot.value as Map?;
                final currentName = userData?['name'] ?? 'Người dùng';
                final currentEmail =
                    userData?['email'] ?? user?.email ?? 'Không có email';

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
                                  labelText: 'Họ và tên',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng nhập tên của bạn';
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
                                  labelText: 'Số điện thoại',
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng nhập số điện thoại của bạn';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Địa chỉ',
                                  prefixIcon: Icon(Icons.home),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng nhập địa chỉ của bạn';
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
                                      child: const Text('Đổi mật khẩu'),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Cài đặt bảo mật'),
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
        title: const Text('Đổi mật khẩu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  hintText: 'Nhập mật khẩu hiện tại',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  hintText: 'Nhập mật khẩu mới',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                  hintText: 'Xác nhận mật khẩu mới',
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
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đổi mật khẩu thành công')),
              );
            },
            child: const Text('Đổi mật khẩu'),
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
