import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
import '../main.dart';
import '../services/camera_service.dart';

class FaceRegistrationCameraPage extends StatefulWidget {
  @override
  _FaceRegistrationCameraPageState createState() =>
      _FaceRegistrationCameraPageState();
}

class _FaceRegistrationCameraPageState
    extends State<FaceRegistrationCameraPage> {
  final CameraService _cameraService = CameraService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera(cameras);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not available')),
        );
      }
    }
  }

  Future<void> _startContinuousCapture() async {
    if (!_cameraService.isCameraReady) return;

    setState(() {
      _isProcessing = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Starting continuous capture - Please slowly move your head at different angles',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }

    await _cameraService.startFaceRegistration((progress) {
      if (mounted) {
        setState(() {});
      }
    });

    setState(() {
      _isProcessing = false;
    });

    if (_cameraService.currentImageCount >= _cameraService.targetImageCount) {
      await _completeRegistration();
    }
  }

  Future<void> _completeRegistration() async {
    setState(() {
      _isProcessing = true;
    });

    final success = await _cameraService.saveFaceDataToFirebase();

    setState(() {
      _isProcessing = false;
    });

    if (success) {
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
                    'Saved ${_cameraService.currentImageCount} images to database.',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total data size: ${_cameraService.calculateTotalSize().toStringAsFixed(2)} KB',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your face has been registered for smart access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _stopContinuousCapture() {
    _cameraService.stopFaceRegistration();
    setState(() {});
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
    _cameraService.dispose();
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
            if (_cameraService.currentImageCount > 0) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _cameraService.currentImageCount /
                _cameraService.targetImageCount,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Image ${_cameraService.currentImageCount} of ${_cameraService.targetImageCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${((_cameraService.currentImageCount / _cameraService.targetImageCount) * 100).round()}%',
                ),
                _cameraService.isCapturing
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                if (_cameraService.isCameraReady &&
                    _cameraService.controller != null &&
                    _cameraService.controller!.value.isInitialized)
                  CameraPreview(_cameraService.controller!)
                else
                  _buildCameraError(),
                Container(
                  width: 250,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _cameraService.isCapturing
                          ? Colors.red
                          : Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 60,
                        color: _cameraService.isCapturing
                            ? Colors.red
                            : Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Place face here',
                        style: TextStyle(
                          color: _cameraService.isCapturing
                              ? Colors.red
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _cameraService.isCapturing
                              ? 'Capturing... Slowly move head\n${_cameraService.currentImageCount}/${_cameraService.targetImageCount} images'
                              : 'Place face in frame\nThen start continuous capture',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        if (!_cameraService.isCapturing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'We will automatically capture 60 images from different angles',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Processing image...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control buttons
          Expanded(
            flex: 1,
            child: Center(
              child: _isProcessing && !_cameraService.isCapturing
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
          child: const Text('Try again'),
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
        Text('Saving to database...', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_cameraService.isCapturing)
          FloatingActionButton.large(
            onPressed:
                _cameraService.isCameraReady ? _startContinuousCapture : null,
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
          _cameraService.isCapturing
              ? 'Tap to stop capture'
              : 'Tap to start continuous capture',
          style: const TextStyle(fontSize: 16),
        ),
        if (_cameraService.currentImageCount > 0 &&
            !_cameraService.isCapturing) ...[
          const SizedBox(height: 8),
          Text(
            '${_cameraService.currentImageCount} images ready',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit registration?'),
        content: Text(
          'You have ${_cameraService.currentImageCount} captured images. Are you sure you want to exit?',
        ),
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
