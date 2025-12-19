import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CameraService {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  int _currentImageCount = 0;
  final int _targetImageCount = 60;

  List<String> _base64Images = [];

  CameraController? get controller => _controller;
  bool get isCameraReady => _isCameraReady;
  bool get isCapturing => _isCapturing;
  int get currentImageCount => _currentImageCount;
  int get targetImageCount => _targetImageCount;

  // Initialize camera
  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
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

    _initializeControllerFuture = _controller.initialize();
    await _initializeControllerFuture;
    _isCameraReady = true;
  }

  // Take picture and convert to base64
  Future<String?> captureImage() async {
    if (!_isCameraReady || !_controller.value.isInitialized) {
      return null;
    }

    try {
      final XFile image = await _controller.takePicture();
      final File imageFile = File(image.path);

      // Convert to base64
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Clean up
      await imageFile.delete();

      return base64Image;
    } catch (e) {
      return null;
    }
  }

  // Start face registration
  Future<void> startFaceRegistration(Function(int) onProgress) async {
    _isCapturing = true;
    _base64Images.clear();
    _currentImageCount = 0;

    for (int i = 0; i < _targetImageCount; i++) {
      if (!_isCapturing) break;

      final image = await captureImage();
      if (image != null) {
        _base64Images.add(image);
        _currentImageCount++;
        onProgress(_currentImageCount);
      }

      // Delay between captures
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isCapturing = false;
  }

  // Stop face registration
  void stopFaceRegistration() {
    _isCapturing = false;
  }

  // Save face data to Firebase
  Future<bool> saveFaceDataToFirebase() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _base64Images.isEmpty) return false;

    try {
      final DatabaseReference userRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}',
      );

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

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get angle description
  String _getAngleDescription(int index) {
    if (index < 20) return 'front';
    if (index < 40) return 'left side';
    return 'right side';
  }

  // Calculate total data size
  double calculateTotalSize() {
    int totalBytes = 0;
    for (var image in _base64Images) {
      totalBytes += image.length;
    }
    return totalBytes / 1024;
  }

  // Dispose camera
  void dispose() {
    _controller.dispose();
  }
}
