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

  // เริ่มต้นกล้อง
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('ข้อผิดพลาดกล้อง: $e');
  }

  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// เครื่องมือจำแนกเสียง TFLite - VERSION ที่แก้ไขแล้ว
// -----------------------------------------------------------------------------
class VoiceClassifier {
  static const String modelFile = 'models/model.tflite';
  static const String labelFile = 'models/voice_labels.txt';

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      // โหลดโมเดล
      _interpreter = await Interpreter.fromAsset(modelFile);

      // โหลดป้ายกำกับ
      _labels = await _loadLabelsFromAssets();

      _isLoaded = true;
      debugPrint('โหลดโมเดลเสียงสำเร็จแล้ว');
      debugPrint('ป้ายกำกับ: $_labels');

      // Debug ข้อมูลโมเดล
      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();
      debugPrint('Input tensors: $inputTensors');
      debugPrint('Output tensors: $outputTensors');
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดโมเดลเสียง: $e');
      _isLoaded = false;
    }
  }

  Future<List<String>> _loadLabelsFromAssets() async {
    // คืนค่าป้ายกำกับเริ่มต้น
    return [
      'bat_den',
      'tat_den',
      'bat_quat',
      'tat_quat',
      'mo_cua',
      'dong_cua',
      'bat_tat_ca',
      'tat_tat_ca',
      'bat_den_phong_khach',
      'tat_den_phong_khach',
      'tat_den_phong_ngu',
      'bat_den_phong_ngu',
      'tat_den_phong_bep',
      'bat_den_phong_bep',
    ];
  }

  // ประมวลผลเสียงล่วงหน้า - VERSION ที่แก้ไขแล้ว
  List<List<double>> _preprocessAudio(List<double> audioData) {
    try {
      // รับรูปร่างอินพุตจริงจากโมเดล
      final inputTensor = _interpreter.getInputTensors().first;
      final inputShape = inputTensor.shape;
      debugPrint('รูปร่างอินพุต: $inputShape');

      const int inputLength = 16000; // ค่าเริ่มต้นสำหรับโมเดลเสียง

      // สร้างอาร์เรย์ 2D ด้วยรูปร่างที่เหมาะสมสำหรับโมเดล
      List<List<double>> processedInput = [];

      // การประมวลผลแบบง่าย - เติมหรือตัดให้มีความยาวตามที่คาดหวัง
      List<double> processedAudio = List<double>.filled(inputLength, 0.0);
      int length =
          audioData.length < inputLength ? audioData.length : inputLength;

      for (int i = 0; i < length; i++) {
        processedAudio[i] = audioData[i];
      }

      // ปรับรูปร่างใหม่สำหรับอินพุตโมเดลตามรูปร่างจริง
      if (inputShape.length == 2) {
        // รูปร่าง: [1, inputLength]
        processedInput.add(processedAudio);
      } else if (inputShape.length == 1) {
        // รูปร่าง: [inputLength]
        processedInput = [processedAudio];
      }

      return processedInput;
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการประมวลผลเสียง: $e');
      return [List<double>.filled(16000, 0.0)];
    }
  }

  // จำแนกคำสั่งเสียงจากคุณลักษณะเสียง - อัปเดตแล้ว
  Map<String, double> classifyVoiceCommand(List<double> audioFeatures) {
    if (!_isLoaded) {
      debugPrint('โมเดลยังไม่โหลด');
      return {};
    }

    try {
      // ประมวลผลเสียงล่วงหน้า
      final input = _preprocessAudio(audioFeatures);

      // เตรียมบัฟเฟอร์เอาต์พุต
      var outputBuffer = List<double>.filled(_labels.length, 0.0);

      // เรียกใช้การอนุมาน - ใช้รูปแบบที่เรียบง่าย
      _interpreter.run(input, outputBuffer);

      debugPrint('ผลลัพธ์ดิบ: $outputBuffer');

      // ประมวลผลผลลัพธ์
      final Map<String, double> labeledProb = {};

      for (int i = 0; i < outputBuffer.length && i < _labels.length; i++) {
        labeledProb[_labels[i]] = outputBuffer[i];
      }

      debugPrint('ผลการจำแนก: $labeledProb');
      return labeledProb;
    } catch (e) {
      debugPrint('ข้อผิดพลาดในกระบวนการจำแนกเสียง: $e');
      return {};
    }
  }

  // จำแนกจากคำสั่งข้อความ (สำรอง)
  Map<String, double> classifyTextCommand(String textCommand) {
    if (!_isLoaded) return {};

    final lowerCommand = textCommand.toLowerCase();
    Map<String, double> results = {};

    // จับคู่คำหลักด้วยคะแนนความเชื่อมั่น
    if (lowerCommand.contains('bật đèn') || lowerCommand.contains('mở đèn')) {
      results['bat_den'] = 0.95;
    } else if (lowerCommand.contains('tắt đèn') ||
        lowerCommand.contains('đóng đèn')) {
      results['tat_den'] = 0.95;
    } else if (lowerCommand.contains('bật quạt') ||
        lowerCommand.contains('mở quạt')) {
      results['bat_quat'] = 0.90;
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt')) {
      results['tat_quat'] = 0.90;
    } else if (lowerCommand.contains('mở cửa') ||
        lowerCommand.contains('mở khóa cửa')) {
      results['mo_cua'] = 0.85;
    } else if (lowerCommand.contains('đóng cửa') ||
        lowerCommand.contains('khóa cửa')) {
      results['dong_cua'] = 0.85;
    } else if (lowerCommand.contains('bật tất cả') ||
        lowerCommand.contains('mở tất cả')) {
      results['bat_tat_ca'] = 0.80;
    } else if (lowerCommand.contains('tắt tất cả') ||
        lowerCommand.contains('đóng tất cả')) {
      results['tat_tat_ca'] = 0.80;
    } else if (lowerCommand.contains('phòng khách')) {
      if (lowerCommand.contains('bật') || lowerCommand.contains('mở')) {
        results['bat_den_phong_khach'] = 0.85;
      } else if (lowerCommand.contains('tắt') ||
          lowerCommand.contains('đóng')) {
        results['tat_den_phong_khach'] = 0.85;
      }
    } else if (lowerCommand.contains('phòng ngủ')) {
      if (lowerCommand.contains('bật') || lowerCommand.contains('mở')) {
        results['bat_den_phong_ngu'] = 0.85;
      } else if (lowerCommand.contains('tắt') ||
          lowerCommand.contains('đóng')) {
        results['tat_den_phong_ngu'] = 0.85;
      }
    } else if (lowerCommand.contains('phòng bếp')) {
      if (lowerCommand.contains('bật') || lowerCommand.contains('mở')) {
        results['bat_den_phong_bep'] = 0.85;
      } else if (lowerCommand.contains('tắt') ||
          lowerCommand.contains('đóng')) {
        results['tat_den_phong_bep'] = 0.85;
      }
    } else if (lowerCommand.contains('bật camera') ||
        lowerCommand.contains('mở camera')) {
      results['bat_camera'] = 0.70;
    } else if (lowerCommand.contains('tắt camera') ||
        lowerCommand.contains('đóng camera')) {
      results['tat_camera'] = 0.70;
    } else if (lowerCommand.contains('trạng thái') ||
        lowerCommand.contains('tình trạng')) {
      results['trang_thai'] = 0.65;
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
// แอปพลิเคชันหลัก
// -----------------------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cardStyle = CardTheme(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return MaterialApp(
      title: 'บ้านอัจฉริยะ Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.teal),
        cardTheme: const CardThemeData(
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
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
// หน้าเข้าสู่ระบบ
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

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 30));

      await _createUserProfile(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'เข้าสู่ระบบล้มเหลว';
      if (e.code == 'user-not-found') {
        errorMessage = 'ไม่พบบัญชีผู้ใช้';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'รหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'ข้อผิดพลาดในการเชื่อมต่อเครือข่าย';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('การเชื่อมต่อหมดเวลา')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ข้อผิดพลาด: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    try {
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        await userRef.set({
          'name': user.displayName ?? 'ผู้ใช้',
          'email': user.email,
          'phone': '',
          'address': '',
          'createdAt': ServerValue.timestamp,
          'updatedAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการสร้างโปรไฟล์ผู้ใช้: $e');
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
                      'บ้านอัจฉริยะ Pro',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'อีเมล',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || v.isEmpty
                          ? 'กรุณากรอกอีเมลของคุณ'
                          : null,
                      onChanged: (v) => email = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty
                          ? 'กรุณากรอกรหัสผ่านของคุณ'
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
                                'เข้าสู่ระบบ',
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
                        "ยังไม่มีบัญชี? ลงทะเบียน",
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
// หน้าลงทะเบียน
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

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 30));

      await userCredential.user!
          .updateDisplayName(name.isEmpty ? 'ผู้ใช้' : name);
      await _createUserProfile(userCredential.user!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลงทะเบียนสำเร็จ!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'ลงทะเบียนล้มเหลว';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'อีเมลนี้ถูกใช้แล้ว';
      } else if (e.code == 'weak-password') {
        errorMessage = 'รหัสผ่านอ่อนเกินไป';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'ข้อผิดพลาดในการเชื่อมต่อเครือข่าย';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('การเชื่อมต่อหมดเวลา')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ข้อผิดพลาด: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUserProfile(User user) async {
    try {
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/${user.uid}');
      await userRef.set({
        'name': name.isEmpty ? 'ผู้ใช้' : name,
        'email': user.email,
        'phone': '',
        'address': '',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการสร้างโปรไฟล์ผู้ใช้: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงทะเบียน'),
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
                    'สร้างบัญชี',
                    style: TextStyle(fontSize: 20, color: Colors.teal),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ชื่อและนามสกุล',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'กรุณากรอกชื่อของคุณ' : null,
                    onChanged: (v) => name = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'อีเมล',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'กรุณากรอกอีเมลของคุณ' : null,
                    onChanged: (v) => email = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'รหัสผ่าน',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6
                        ? 'อย่างน้อย 6 ตัวอักษร'
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
                            'ลงทะเบียน',
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
// หน้าหลัก - การควบคุมเสียงขั้นสูงด้วย TFLite
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

  // สถานะอุปกรณ์
  bool isDoorOn = false;
  bool isLivingLightOn = false;
  bool isBedroomLightOn = false;
  bool isBathroomLightOn = false;
  bool isFanOn = false;
  bool isCameraOn = false;

  // เซ็นเซอร์
  double? temperature;
  double? humidity;

  // การรู้จำเสียง
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  // เครื่องมือจำแนกเสียง TFLite
  final VoiceClassifier _voiceClassifier = VoiceClassifier();
  bool _isModelLoaded = false;
  bool _useTFLite = true;

  // เครื่องเล่นเสียง
  final AudioPlayer _audioPlayer = AudioPlayer();

  // รายการการแจ้งเตือน
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;

  // Listeners
  StreamSubscription? _controlSubscription;
  StreamSubscription? _sensorsSubscription;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _cameraSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _listenControl();
    await _listenSensors();
    await _listenNotifications();
    await _listenCamera();

    // เริ่มต้นระบบเสียง
    _speechToText = stt.SpeechToText();
    await _initSpeech();
    await _loadTFLiteModel();
  }

  Future<void> _loadTFLiteModel() async {
    try {
      await _voiceClassifier.loadModel();
      if (!mounted) return;

      setState(() {
        _isModelLoaded = _voiceClassifier.isLoaded;
      });

      if (_isModelLoaded) {
        debugPrint('โหลดโมเดล TFLite สำเร็จแล้ว');
      } else {
        debugPrint('โหลดโมเดล TFLite ล้มเหลว');
        setState(() {
          _useTFLite = false;
        });
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดโมเดล TFLite: $e');
      if (mounted) {
        setState(() {
          _isModelLoaded = false;
          _useTFLite = false;
        });
      }
    }
  }

  /// เล่นเอฟเฟกต์เสียง
  Future<void> _playSound(String soundType) async {
    try {
      // ตรวจสอบว่าเครื่องเล่นเสียงพร้อมหรือไม่
      if (_audioPlayer.state != PlayerState.playing) {
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
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการเล่นเสียง: $e');
    }
  }

  /// เริ่มต้นบริการรู้จำเสียง
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (!mounted) return;

    setState(() {});
    if (!_speechEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('การรู้จำเสียงไม่พร้อมใช้งาน')),
      );
    }
  }

  /// เริ่มฟังอินพุตเสียง
  void _startListening() async {
    if (!_speechEnabled) return;
    await _playSound('voice_start');

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _lastWords =
          _isModelLoaded && _useTFLite ? 'AI กำลังฟัง...' : 'กำลังฟัง...';
    });

    await _speechToText.listen(
      onResult: _onSpeechResultWithTFLite,
      localeId: 'vi_VN', // เปลี่ยนเป็นภาษาเวียดนาม
      listenFor: const Duration(seconds: 10),
    );
  }

  /// หยุดฟังอินพุตเสียง
  void _stopListening() async {
    await _speechToText.stop();
    await _playSound('voice_stop');
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  /// ประมวลผลเสียงด้วย TFLite
  void _onSpeechResultWithTFLite(stt.SpeechRecognitionResult result) {
    if (!mounted) return;

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

  /// ประมวลผลคำสั่งเสียงขั้นสูงด้วย TFLite
  Future<void> _processVoiceCommandWithTFLite(String command) async {
    debugPrint('คำสั่งเสียงด้วย TFLite: "$command"');

    if (_isModelLoaded && _useTFLite) {
      // ลองจำแนกด้วย TFLite ก่อน
      final topCommand = _voiceClassifier.getTopCommandFromText(command);

      if (topCommand != null) {
        debugPrint(
            'TFLite ตรวจพบ: ${topCommand.key} ด้วยความเชื่อมั่น: ${topCommand.value}');
        await _executeCommandByLabel(topCommand.key, command);
        return;
      }
    }

    // กลับไปประมวลผลแบบดั้งเดิม
    await _processVoiceCommand(command);
  }

  /// ประมวลผลคำสั่งเสียงแบบดั้งเดิม
  Future<void> _processVoiceCommand(String command) async {
    debugPrint('คำสั่งเสียงแบบดั้งเดิม: "$command"');

    final lowerCommand = command.toLowerCase();
    String feedback = 'ไม่เข้าใจคำสั่ง';

    // คำสั่งเสียงภาษาเวียดนาม
    if (lowerCommand.contains('mở cửa') ||
        lowerCommand.contains('mở khóa cửa')) {
      await _setControl('servo_angle', '90');
      await _playSound('switch_on');
      feedback = 'เปิดประตูแล้ว';
    } else if (lowerCommand.contains('đóng cửa') ||
        lowerCommand.contains('khóa cửa')) {
      await _setControl('servo_angle', '0');
      await _playSound('switch_off');
      feedback = 'ปิดประตูแล้ว';
    } else if (lowerCommand.contains('bật đèn phòng khách') ||
        lowerCommand.contains('mở đèn phòng khách') ||
        lowerCommand.contains('đèn phòng khách bật')) {
      await _setControl('led1', true);
      await _playSound('switch_on');
      feedback = 'เปิดไฟห้องนั่งเล่นแล้ว';
    } else if (lowerCommand.contains('tắt đèn phòng khách') ||
        lowerCommand.contains('đóng đèn phòng khách') ||
        lowerCommand.contains('đèn phòng khách tắt')) {
      await _setControl('led1', false);
      await _playSound('switch_off');
      feedback = 'ปิดไฟห้องนั่งเล่นแล้ว';
    } else if (lowerCommand.contains('bật đèn phòng ngủ') ||
        lowerCommand.contains('mở đèn phòng ngủ') ||
        lowerCommand.contains('đèn phòng ngủ bật')) {
      await _setControl('led2', true);
      await _playSound('switch_on');
      feedback = 'เปิดไฟห้องนอนแล้ว';
    } else if (lowerCommand.contains('tắt đèn phòng ngủ') ||
        lowerCommand.contains('đóng đèn phòng ngủ') ||
        lowerCommand.contains('đèn phòng ngủ tắt')) {
      await _setControl('led2', false);
      await _playSound('switch_off');
      feedback = 'ปิดไฟห้องนอนแล้ว';
    } else if (lowerCommand.contains('bật đèn phòng tắm') ||
        lowerCommand.contains('mở đèn phòng tắm') ||
        lowerCommand.contains('đèn phòng tắm bật')) {
      await _setControl('led3', true);
      await _playSound('switch_on');
      feedback = 'เปิดไฟห้องน้ำแล้ว';
    } else if (lowerCommand.contains('tắt đèn phòng tắm') ||
        lowerCommand.contains('đóng đèn phòng tắm') ||
        lowerCommand.contains('đèn phòng tắm tắt')) {
      await _setControl('led3', false);
      await _playSound('switch_off');
      feedback = 'ปิดไฟห้องน้ำแล้ว';
    } else if (lowerCommand.contains('bật quạt') ||
        lowerCommand.contains('mở quạt') ||
        lowerCommand.contains('quạt bật')) {
      await _setControl('motor', true);
      await _playSound('switch_on');
      feedback = 'เปิดพัดลมแล้ว';
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt') ||
        lowerCommand.contains('quạt tắt')) {
      await _setControl('motor', false);
      await _playSound('switch_off');
      feedback = 'ปิดพัดลมแล้ว';
    } else if (lowerCommand.contains('bật tất cả đèn') ||
        lowerCommand.contains('mở tất cả đèn') ||
        lowerCommand.contains('tất cả đèn bật')) {
      await _toggleAllDevices(true);
      feedback = 'เปิดไฟทั้งหมดแล้ว';
    } else if (lowerCommand.contains('tắt tất cả đèn') ||
        lowerCommand.contains('đóng tất cả đèn') ||
        lowerCommand.contains('tất cả đèn tắt')) {
      await _toggleAllDevices(false);
      feedback = 'ปิดไฟทั้งหมดแล้ว';
    } else if (lowerCommand.contains('mở camera') ||
        lowerCommand.contains('bật camera') ||
        lowerCommand.contains('xem camera')) {
      await _startCamera();
      feedback = 'กำลังเปิดกล้อง';
    } else if (lowerCommand.contains('đóng camera') ||
        lowerCommand.contains('tắt camera') ||
        lowerCommand.contains('dừng camera')) {
      await _stopCamera();
      feedback = 'กำลังปิดกล้อง';
    } else if (lowerCommand.contains('trạng thái') ||
        lowerCommand.contains('tình trạng')) {
      feedback =
          'อุณหภูมิ: ${temperature?.toStringAsFixed(1) ?? "--"}°C, ความชื้น: ${humidity?.toStringAsFixed(1) ?? "--"}%';
    }

    // เพิ่มการแจ้งเตือนสำหรับคำสั่งเสียง
    await _addNotification('คำสั่งเสียง: $command', 'voice');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// ประมวลผลคำสั่งตามป้ายกำกับ
  Future<void> _executeCommandByLabel(
      String commandLabel, String originalCommand) async {
    String feedback = 'คำสั่งถูกดำเนินการแล้ว';
    bool commandExecuted = true;

    switch (commandLabel) {
      case 'bat_den':
      case 'bat_den_phong_khach':
        await _setControl('led1', true);
        await _playSound('switch_on');
        feedback = 'เปิดไฟห้องนั่งเล่นแล้ว';
        break;

      case 'tat_den':
      case 'tat_den_phong_khach':
        await _setControl('led1', false);
        await _playSound('switch_off');
        feedback = 'ปิดไฟห้องนั่งเล่นแล้ว';
        break;

      case 'bat_quat':
        await _setControl('motor', true);
        await _playSound('switch_on');
        feedback = 'เปิดพัดลมแล้ว';
        break;

      case 'tat_quat':
        await _setControl('motor', false);
        await _playSound('switch_off');
        feedback = 'ปิดพัดลมแล้ว';
        break;

      case 'mo_cua':
        await _setControl('servo_angle', '90');
        await _playSound('switch_on');
        feedback = 'เปิดประตูแล้ว';
        break;

      case 'dong_cua':
        await _setControl('servo_angle', '0');
        await _playSound('switch_off');
        feedback = 'ปิดประตูแล้ว';
        break;

      case 'bat_tat_ca':
        await _toggleAllDevices(true);
        feedback = 'เปิดอุปกรณ์ทั้งหมดแล้ว';
        break;

      case 'tat_tat_ca':
        await _toggleAllDevices(false);
        feedback = 'ปิดอุปกรณ์ทั้งหมดแล้ว';
        break;

      case 'bat_den_phong_ngu':
        await _setControl('led2', true);
        await _playSound('switch_on');
        feedback = 'เปิดไฟห้องนอนแล้ว';
        break;

      case 'tat_den_phong_ngu':
        await _setControl('led2', false);
        await _playSound('switch_off');
        feedback = 'ปิดไฟห้องนอนแล้ว';
        break;

      case 'bat_den_phong_bep':
        await _setControl('led3', true);
        await _playSound('switch_on');
        feedback = 'เปิดไฟห้องครัวแล้ว';
        break;

      case 'tat_den_phong_bep':
        await _setControl('led3', false);
        await _playSound('switch_off');
        feedback = 'ปิดไฟห้องครัวแล้ว';
        break;

      case 'bat_camera':
        await _startCamera();
        feedback = 'กำลังเปิดกล้อง';
        break;

      case 'tat_camera':
        await _stopCamera();
        feedback = 'กำลังปิดกล้อง';
        break;

      case 'trang_thai':
        feedback =
            'อุณหภูมิ: ${temperature?.toStringAsFixed(1) ?? "--"}°C, ความชื้น: ${humidity?.toStringAsFixed(1) ?? "--"}%';
        break;

      default:
        commandExecuted = false;
        // กลับไปประมวลผลแบบดั้งเดิม
        await _processVoiceCommand(originalCommand);
        return;
    }

    if (commandExecuted) {
      // เพิ่มการแจ้งเตือนสำหรับคำสั่งที่ AI ตรวจจับ
      await _addNotification('คำสั่ง AI: $commandLabel', 'voice_ai');

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

  /// เปิด/ปิดอุปกรณ์ทั้งหมด
  Future<void> _toggleAllDevices(bool value) async {
    try {
      await _playSound(value ? 'switch_on' : 'switch_off');

      // ส่งคำสั่งทั้งหมดพร้อมกัน
      await Future.wait([
        _setControl('servo_angle', value ? '90' : '0'),
        _setControl('led1', value),
        _setControl('led2', value),
        _setControl('led3', value),
        _setControl('motor', value),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  value ? 'เปิดอุปกรณ์ทั้งหมดแล้ว' : 'ปิดอุปกรณ์ทั้งหมดแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ข้อผิดพลาด: $e')),
        );
      }
    }
  }

  // เพิ่มการแจ้งเตือนไปยัง Firebase
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
      debugPrint('ข้อผิดพลาดในการเพิ่มการแจ้งเตือน: $e');
    }
  }

  // ตรวจสอบการแจ้งเตือนอุณหภูมิ
  void _checkTemperatureAlert(double? temp) {
    if (temp != null && temp > 30) {
      _addNotification(
          '🚨 อุณหภูมิสูง: ${temp.toStringAsFixed(1)}°C. กรุณาเปิดพัดลมหรือเครื่องปรับอากาศ',
          'temperature_alert');
    }
  }

  Future<void> _setControl(String key, dynamic value) async {
    try {
      // ส่งคำสัไปยัง Firebase - Raspberry Pi จะฟัง
      await _controlRef
          .child(key)
          .set(value is bool ? (value ? 'ON' : 'OFF') : value);
      debugPrint('ส่งคำสัควบคุมแล้ว: $key = $value');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตล้มเหลว: $e')),
        );
      }
    }
  }

  // วิธีการควบคุมกล้อง
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
          SnackBar(content: Text('ข้อผิดพลาดในการเริ่มต้นกล้อง: $e')),
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
      debugPrint('ข้อผิดพลาดในการหยุดกล้อง: $e');
    }
  }

  Future<void> _listenControl() async {
    _controlSubscription = _controlRef.onValue.listen((event) {
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

  Future<void> _listenCamera() async {
    _cameraSubscription = _cameraRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          isCameraOn = _toBool(data['status']);
        });
      }
    });
  }

  Future<void> _listenSensors() async {
    _sensorsSubscription = _sensorsRef.onValue.listen((event) {
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

        // เรียกตรวจสอบการแจ้งเตือนอุณหภูมิ
        _checkTemperatureAlert(temperature);
      }
    });
  }

  Future<void> _listenNotifications() async {
    _notificationsSubscription =
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

  // นำทางไปยังหน้าการแจ้งเตือน
  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              NotificationsPage(notifications: _notifications)),
    );
  }

  // สลับโหมด TFLite
  void _toggleTFLiteMode() {
    if (!_isModelLoaded) return;

    setState(() {
      _useTFLite = !_useTFLite;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useTFLite
              ? 'โหมดรู้จำเสียง AI: เปิด'
              : 'โหมดรู้จำเสียงปกติ: เปิด'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ฟังก์ชันช่วยแปลงรูปแบบจากฐานข้อมูล
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

  // ฟังก์ชันดึงข้อมูลแบบซ้อน
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

  // แสดงกล่องโต้ตอบยืนยันการออกจากระบบ
  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ออกจากระบบ'),
          content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child:
                  const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // นำทางไปยังหน้าตั้งค่า
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  // นำทางไปยังหน้ากล้อง
  void _navigateToCamera() {
    _startCamera();
  }

  // คำทักทายตามเวลา
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'สวัสดีตอนเช้า,';
    if (hour < 18) return 'สวัสดีตอนบ่าย,';
    return 'สวัสดีตอนเย็น,';
  }

  // วันที่ที่จัดรูปแบบ
  String getFormattedDate() {
    final now = DateTime.now();
    final months = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  // ป้ายกำกับอุณหภูมิ
  String getTempLabel(double? temp) {
    if (temp == null) return '';
    if (temp > 25) return 'อุ่น';
    if (temp > 20) return 'สบาย';
    return 'เย็น';
  }

  // ป้ายกำกับความชื้น
  String getHumidityLabel(double? hum) {
    if (hum == null) return '';
    if (hum > 60) return 'สูง';
    if (hum > 40) return 'ปกติ';
    return 'ต่ำ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ส่วนหัว
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
                    const Text('บ้านอัจฉริยะ',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.videocam),
                      onPressed: _navigateToCamera,
                      tooltip: 'กล้อง',
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: _navigateToNotifications,
                          tooltip: 'การแจ้งเตือน',
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
                      tooltip: 'การตั้งค่า',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // สถานที่และวันที่
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
                      'ที่ดานัง',
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

          // การ์ดอุณหภูมิและความชื้น
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
                          const Text('อุณหภูมิ'),
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
                          const Text('ความชื้น'),
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

          // รายการอุปกรณ์
          // รายการอุปกรณ์
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // สลับโหมดรู้จำเสียง
                Card(
                  child: ListTile(
                    leading: Icon(
                      _useTFLite && _isModelLoaded
                          ? Icons.auto_awesome
                          : Icons.mic,
                      color: _useTFLite && _isModelLoaded
                          ? Colors.amber
                          : Colors.grey,
                    ),
                    title: const Text('การรู้จำเสียง AI'),
                    subtitle: Text(_isModelLoaded
                        ? 'ใช้โมเดล TFLite สำหรับคำสั่งเสียง'
                        : 'โมเดล TFLite กำลังโหลด...'),
                    trailing: Switch(
                      value: _useTFLite && _isModelLoaded,
                      onChanged: _isModelLoaded
                          ? (bool value) {
                              _toggleTFLiteMode();
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ส่วนกล้อง
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'กล้องรักษาความปลอดภัย',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('สด', style: TextStyle(color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.videocam,
                        size: 40, color: Colors.blue),
                    title: const Text('กล้องรักษาความปลอดภัย',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('ตรวจสอบบ้าน'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ดูสด'),
                      onPressed: _navigateToCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ส่วนอุปกรณ์อัจฉริยะ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'อุปกรณ์อัจฉริยะ',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('รีเฟรช', style: TextStyle(color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 8),

                // สวิตช์หลักสำหรับอุปกรณ์ทั้งหมด
                Card(
                  child: SwitchListTile(
                    title: const Text('อุปกรณ์ทั้งหมด'),
                    value: isDoorOn &&
                        isLivingLightOn &&
                        isBedroomLightOn &&
                        isBathroomLightOn &&
                        isFanOn,
                    onChanged: (bool value) async {
                      await _toggleAllDevices(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // แถวแรก - ประตูและไฟห้องนั่งเล่น
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
                              const Text('ประตูอัจฉริยะ',
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
                              const Text('ไฟห้องนั่งเล่น',
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

                // แถวที่สอง - ไฟห้องนอนและห้องน้ำ
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
                              const Text('ไฟห้องนอน',
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
                              const Text('ไฟห้องน้ำ',
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

                // แถวที่สาม - พัดลม
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
                              const Text('พัดลมอัจฉริยะ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Text('ทำความเย็น',
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

      // ปุ่มควบคุมเสียงลอย
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

      // แถบนำทางด้านล่าง
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
    // ปิด listeners
    _controlSubscription?.cancel();
    _sensorsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _cameraSubscription?.cancel();

    _voiceClassifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// หน้าการแจ้งเตือน
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
        title: const Text('การแจ้งเตือน'),
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
            tooltip: 'ทำเครื่องหมายทั้งหมดว่าอ่านแล้ว',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showClearAllDialog,
            tooltip: 'ลบทั้งหมด',
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
                    'ไม่มีการแจ้งเตือน',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'การแจ้งเตือนจะปรากฏที่นี่',
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
      debugPrint('ข้อผิดพลาดในการทำเครื่องหมายการแจ้งเตือนว่าอ่านแล้ว: $e');
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
          const SnackBar(
              content: Text('ทำเครื่องหมายการแจ้งเตือนทั้งหมดว่าอ่านแล้ว')),
        );
      }
    } catch (e) {
      debugPrint(
          'ข้อผิดพลาดในการทำเครื่องหมายการแจ้งเตือนทั้งหมดว่าอ่านแล้ว: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.child(notificationId).remove();
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการลบการแจ้งเตือน: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationsRef.remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบการแจ้งเตือนทั้งหมดแล้ว')),
        );
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการลบการแจ้งเตือนทั้งหมด: $e');
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบการแจ้งเตือนทั้งหมด'),
        content: const Text(
            'คุณแน่ใจหรือไม่ว่าต้องการลบการแจ้งเตือนทั้งหมด? การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            child: const Text('ลบทั้งหมด', style: TextStyle(color: Colors.red)),
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
        title: const Text('รายละเอียดการแจ้งเตือน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ข้อความ: $message'),
            const SizedBox(height: 8),
            Text('ประเภท: $type'),
            const SizedBox(height: 8),
            Text('เวลา: ${timeFormat.format(dateTime)}'),
            Text('วันที่: ${dateFormat.format(dateTime)}'),
            const SizedBox(height: 8),
            Text('สถานะ: ${isRead ? 'อ่านแล้ว' : 'ยังไม่อ่าน'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// หน้ากล้อง
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
            debugPrint('WebView กำลังโหลด: $progress%');
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
ข้อผิดพลาดทรัพยากรหน้า:
  รหัส: ${error.errorCode}
  คำอธิบาย: ${error.description}
  ประเภทข้อผิดพลาด: ${error.errorType}
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
        title: const Text('กล้องรักษาความปลอดภัย'),
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
            tooltip: 'รีเฟรชสตรีม',
          ),
        ],
      ),
      body: Column(
        children: [
          // สถานะกล้อง
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
                      'สด',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'กล้องรักษาความปลอดภัย',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // สตรีมกล้อง
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
                            'กำลังเชื่อมต่อกับกล้อง...',
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
                            'ไม่สามารถเชื่อมต่อกับกล้องได้',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองเชื่อมต่ออีกครั้ง'),
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
// หน้าการตั้งค่า
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

  // ฟังก์ชันลงทะเบียนใบหน้าด้วยกล้องจริง
  Future<void> _registerFace() async {
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กล้องไม่พร้อมใช้งาน')),
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
        title: const Text('การตั้งค่า'),
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
            return Center(child: Text('ข้อผิดพลาด: ${snapshot.error}'));
          }

          final userData = snapshot.data?.snapshot.value as Map?;
          final userName = userData?['name'] ?? 'ผู้ใช้';
          final userEmail = userData?['email'] ?? user?.email ?? 'ไม่มีอีเมล';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ส่วนโปรไฟล์
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

              // ส่วนความปลอดภัยกับการลงทะเบียนใบหน้า
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ความปลอดภัย',
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
                      title: const Text('ลงทะเบียนใบหน้า'),
                      subtitle: const Text(
                          'ลงทะเบียนใบหน้าเพื่อการเข้าถึงอย่างชาญฉลาด'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _registerFace,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ส่วนการตั้งค่าแอปพลิเคชัน
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'การตั้งค่าแอปพลิเคชัน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('การแจ้งเตือนแบบพุช'),
                      subtitle: const Text('รับการแจ้งเตือนแบบพุช'),
                      value: _notificationsEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('โหมดมืด'),
                      subtitle: const Text('เปิดธีมมืด'),
                      value: _darkMode,
                      onChanged: (bool value) {
                        setState(() {
                          _darkMode = value;
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('ภาษา'),
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

              // ปุ่มออกจากระบบ
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
                        'ออกจากระบบ',
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
        title: const Text('เลือกภาษา'),
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
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child:
                const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// หน้าลงทะเบียนใบหน้า
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

  // บันทึกภาพเป็น Base64
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
          const SnackBar(content: Text('กล้องไม่พร้อมใช้งาน')),
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
        _showError('ข้อผิดพลาดกล้อง: ${e.description}');
      }
    });
  }

  // แปลงภาพเป็น Base64
  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      return base64Image;
    } catch (e) {
      print('ข้อผิดพลาดในการแปลงภาพ: $e');
      rethrow;
    }
  }

  // เริ่มการถ่ายภาพต่อเนื่อง
  Future<void> _startContinuousCapture() async {
    if (!_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _currentImageCount = 0;
      _base64Images.clear();
    });

    // แจ้งผู้ใช้ให้เคลื่อนไหวใบหน้า
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'เริ่มการถ่ายภาพต่อเนื่อง - กรุณาเคลื่อนไหวศีรษะช้าๆ ในมุมต่างๆ'),
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

  // หยุดการถ่ายภาพต่อเนื่อง
  void _stopContinuousCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;

    setState(() {
      _isCapturing = false;
    });

    // แจ้งผู้ใช้เมื่อถ่ายภาพเสร็จสิ้น
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ถ่ายภาพเสร็จสิ้น! บันทึก $_currentImageCount ภาพแล้ว'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // บันทึกข้อมูลเมื่อถ่ายภาพเสร็จสิ้น
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

      // ถ่ายภาพ
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);

      // แปลงภาพเป็น Base64
      final String base64Image = await _convertImageToBase64(imageFile);

      // บันทึก Base64 image
      _base64Images.add(base64Image);

      // อัปเดตจำนวนภาพ
      setState(() {
        _currentImageCount = _base64Images.length;
        _isProcessing = false;
      });

      print('ถ่ายภาพและแปลงภาพ $_currentImageCount เป็น Base64 แล้ว');

      // ลบไฟล์ชั่วคราว
      await imageFile.delete();
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการถ่ายภาพ: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeRegistration() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('ผู้ใช้ยังไม่ได้เข้าสู่ระบบ');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // บันทึกข้อมูลลง Firebase Database
      final DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/${user.uid}');

      // สร้างโครงสร้างสำหรับบันทึกภาพ
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

      // แจ้งเตือนความสำเร็จ
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
                  Text('ลงทะเบียนสำเร็จ'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ลงทะเบียนใบหน้าเสร็จสิ้นสำเร็จ!'),
                  const SizedBox(height: 16),
                  Text(
                    'บันทึก $_currentImageCount ภาพลงฐานข้อมูลแล้ว',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ขนาดข้อมูลทั้งหมด: ${_calculateTotalSize()} KB',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ใบหน้าของคุณถูกลงทะเบียนสำหรับการเข้าถึงอย่างชาญฉลาดแล้ว',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // ปิดกล่องโต้ตอบ
                    Navigator.pop(context); // กลับไปหน้าการตั้งค่า
                  },
                  child: const Text('ตกลง'),
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
      _showError('ข้อผิดพลาดในการลงทะเบียนเสร็จสิ้น: $e');
    }
  }

  // คำอธิบายมุมถ่ายภาพ
  String _getAngleDescription(int index) {
    if (index < 20) return 'หน้า';
    if (index < 40) return 'ด้านซ้าย';
    return 'ด้านขวา';
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
        title: const Text('ลงทะเบียนใบหน้า'),
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
          // แถบความคืบหน้า
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
                  'ภาพ $_currentImageCount จาก $_targetImageCount',
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
                          'กำลังบันทึก',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const Text('พร้อม'),
              ],
            ),
          ),

          // ตัวอย่างกล้อง
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

                // วงกลมแนะนำใบหน้า
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
                        'วางใบหน้าของคุณที่นี่',
                        style: TextStyle(
                          color: _isCapturing ? Colors.red : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // คำแนะนำ
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
                              ? 'กำลังถ่ายภาพ... เคลื่อนไหวศีรษะช้าๆ\n$_currentImageCount/$_targetImageCount ภาพ'
                              : 'วางใบหน้าของคุณในกรอบ\nจากนั้นเริ่มการถ่ายภาพต่อเนื่อง',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        if (!_isCapturing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'เราจะถ่ายภาพ 60 ภาพจากมุมต่างๆ โดยอัตโนมัติ',
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

                // ตัวบ่งชี้การประมวลผล
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
                            'กำลังประมวลผลภาพ...',
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

          // ปุ่มควบคุม
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
        const Text('กล้องไม่พร้อมใช้งาน'),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _initializeCamera,
          child: const Text('ลองอีกครั้ง'),
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
          'กำลังบันทึกลงฐานข้อมูล...',
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
              ? 'แตะเพื่อหยุดการถ่ายภาพ'
              : 'แตะเพื่อเริ่มการถ่ายภาพต่อเนื่อง',
          style: const TextStyle(fontSize: 16),
        ),
        if (_base64Images.isNotEmpty && !_isCapturing) ...[
          const SizedBox(height: 8),
          Text(
            '$_currentImageCount ภาพพร้อมแล้ว',
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
        title: const Text('ออกจากการลงทะเบียน?'),
        content: Text(
            'คุณมี $_currentImageCount ภาพที่ถ่ายแล้ว คุณแน่ใจหรือไม่ว่าต้องการออก?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('ออก', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// หน้าโปรไฟล์
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
      debugPrint('ข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e');
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
          const SnackBar(content: Text('อัปเดตโปรไฟล์สำเร็จแล้ว')),
        );
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ข้อผิดพลาดในการอัปเดตโปรไฟล์: $e')),
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
        title: const Text('โปรไฟล์'),
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
                  return Center(child: Text('ข้อผิดพลาด: ${snapshot.error}'));
                }

                final userData = snapshot.data?.snapshot.value as Map?;
                final currentName = userData?['name'] ?? 'ผู้ใช้';
                final currentEmail =
                    userData?['email'] ?? user?.email ?? 'ไม่มีอีเมล';

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
                                  labelText: 'ชื่อและนามสกุล',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกชื่อของคุณ';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'อีเมล',
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
                                  labelText: 'หมายเลขโทรศัพท์',
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกหมายเลขโทรศัพท์ของคุณ';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'ที่อยู่',
                                  prefixIcon: Icon(Icons.home),
                                  border: OutlineInputBorder(),
                                ),
                                enabled: _editing,
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกที่อยู่ของคุณ';
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
                                      child: const Text('เปลี่ยนรหัสผ่าน'),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {},
                                      child:
                                          const Text('การตั้งค่าความปลอดภัย'),
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
        title: const Text('เปลี่ยนรหัสผ่าน'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านปัจจุบัน',
                  hintText: 'ป้อนรหัสผ่านปัจจุบัน',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  hintText: 'ป้อนรหัสผ่านใหม่',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  hintText: 'ยืนยันรหัสผ่านใหม่',
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
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จแล้ว')),
              );
            },
            child: const Text('เปลี่ยนรหัสผ่าน'),
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
