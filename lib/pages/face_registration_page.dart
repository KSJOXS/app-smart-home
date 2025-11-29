import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart';

class FaceRegistrationCameraPage extends StatefulWidget {
  @override
  _FaceRegistrationCameraPageState createState() => _FaceRegistrationCameraPageState();
}

class _FaceRegistrationCameraPageState extends State<FaceRegistrationCameraPage> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  int _currentImageCount = 0;
  final int _targetImageCount = 60;
  Timer? _captureTimer;
  List<String> _base64Images = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      _showError('Camera không khả dụng');
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
      setState(() => _isCameraReady = true);
    }).catchError((Object e) {
      if (e is CameraException) {
        _showError('Lỗi camera: ${e.description}');
      }
    });
  }

  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      throw Exception('Lỗi chuyển đổi hình ảnh: $e');
    }
  }

  Future<void> _startContinuousCapture() async {
    if (!_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _currentImageCount = 0;
      _base64Images.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bắt đầu chụp liên tục - Vui lòng di chuyển đầu chậm ở các góc độ khác nhau'),
        duration: Duration(seconds: 5),
      ),
    );

    _captureTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_currentImageCount >= _targetImageCount) {
        _stopContinuousCapture();
        return;
      }
      await _captureSingleImage();
    });
  }

  void _stopContinuousCapture() {
    _captureTimer?.cancel();
    setState(() => _isCapturing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chụp hoàn tất! Đã lưu $_currentImageCount ảnh')),
    );

    if (_currentImageCount >= _targetImageCount) {
      _completeRegistration();
    }
  }

  Future<void> _captureSingleImage() async {
    if (!_isCameraReady || _controller == null || !_controller!.value.isInitialized) return;

    try {
      setState(() => _isProcessing = true);
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);
      final String base64Image = await _convertImageToBase64(imageFile);

      _base64Images.add(base64Image);
      
      setState(() {
        _currentImageCount = _base64Images.length;
        _isProcessing = false;
      });

      await imageFile.delete();
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Lỗi chụp ảnh: $e');
    }
  }

  Future<void> _completeRegistration() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Người dùng chưa đăng nhập');
      return;
    }

    try {
      setState(() => _isProcessing = true);
      final DatabaseReference userRef = FirebaseDatabase.instance.ref('users/${user.uid}');

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

      setState(() => _isProcessing = false);
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Lỗi hoàn tất đăng ký: $e');
    }
  }

  String _getAngleDescription(int index) {
    if (index < 20) return 'trước';
    if (index < 40) return 'bên trái';
    return 'bên phải';
  }

  String _calculateTotalSize() {
    int totalBytes = _base64Images.fold(0, (sum, image) => sum + image.length);
    return (totalBytes / 1024).toStringAsFixed(2);
  }

  void _showSuccessDialog() {
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
              Text('Đã lưu $_currentImageCount ảnh vào cơ sở dữ liệu.', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 8),
              Text('Tổng kích thước dữ liệu: ${_calculateTotalSize()} KB', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('Khuôn mặt của bạn đã được đăng ký để truy cập thông minh.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát đăng ký?'),
        content: Text('Bạn có $_currentImageCount ảnh đã chụp. Bạn có chắc chắn muốn thoát?'),
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
          // Progress Bar
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
                Text('Ảnh $_currentImageCount trên $_targetImageCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${((_currentImageCount / _targetImageCount) * 100).round()}%'),
                _isCapturing
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: const Text('ĐANG GHI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    : const Text('Sẵn sàng'),
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
                      if (_controller != null && _controller!.value.isInitialized) {
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
                    border: Border.all(color: _isCapturing ? Colors.red : Colors.white, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.face, size: 60, color: _isCapturing ? Colors.red : Colors.white.withOpacity(0.8)),
                      const SizedBox(height: 8),
                      Text('Đặt khuôn mặt ở đây', style: TextStyle(color: _isCapturing ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // Instructions
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Text(
                          _isCapturing
                              ? 'Đang chụp... Di chuyển đầu chậm\n$_currentImageCount/$_targetImageCount ảnh'
                              : 'Đặt khuôn mặt trong khung\nSau đó bắt đầu chụp liên tục',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        if (!_isCapturing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Chúng tôi sẽ tự động chụp 60 ảnh từ các góc độ khác nhau',
                            style: TextStyle(color: Colors.white, fontSize: 12),
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
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          SizedBox(height: 16),
                          Text('Đang xử lý ảnh...', style: TextStyle(color: Colors.white, fontSize: 16)),
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
        Text('Đang lưu vào cơ sở dữ liệu...', style: TextStyle(fontSize: 16)),
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
            style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ]
      ],
    );
  }
}