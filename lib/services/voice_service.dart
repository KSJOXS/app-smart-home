import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/voice_classifier.dart';

class VoiceService {
  final VoiceClassifier _classifier = VoiceClassifier();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Audio recording
  bool _isRecording = false;
  bool _isProcessing = false;
  List<double> _audioSamples = [];
  Timer? _recordingTimer;
  
  // Model
  bool _isModelLoaded = false;

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isModelLoaded => _isModelLoaded;

  // Initialize services
  Future<void> init() async {
    await _classifier.loadModel();
    _isModelLoaded = _classifier.isLoaded;
  }

  // Bắt đầu ghi âm
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    _isRecording = true;
    _audioSamples.clear();
    await _playSound('voice_start');
    
    print('🎤 Bắt đầu ghi âm...');
    
    // Giả lập thu thập audio samples
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      // THAY THẾ BẰNG AUDIO RECORDING THẬT
      _collectAudioSamples();
    });
    
    // Tự động dừng sau 3 giây
    Timer(const Duration(seconds: 3), () {
      if (_isRecording) {
        stopRecording();
      }
    });
  }

  // Dừng ghi âm và xử lý
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    _recordingTimer?.cancel();
    _isRecording = false;
    await _playSound('voice_stop');
    
    print('⏹️ Dừng ghi âm. Đã thu được ${_audioSamples.length} samples');
    
    // Xử lý audio
    await _processAudio();
  }

  // Giả lập thu thập audio samples
  void _collectAudioSamples() {
    // THAY THẾ BẰNG AUDIO RECORDING THẬT
    // Đây chỉ là dữ liệu giả lập cho demo
    for (int i = 0; i < 100; i++) {
      _audioSamples.add((DateTime.now().microsecondsSinceEpoch % 100) / 100.0 - 0.5);
    }
  }

  // Xử lý audio và dự đoán
  Future<void> _processAudio() async {
    if (_audioSamples.isEmpty || !_isModelLoaded) {
      print('❌ Không có dữ liệu audio hoặc model chưa sẵn sàng');
      return;
    }

    _isProcessing = true;
    print('🔮 Đang xử lý và dự đoán...');

    try {
      // Dự đoán từ audio samples
      final topCommand = _classifier.getTopCommand(_audioSamples);
      
      if (topCommand != null) {
        final confidence = topCommand.value;
        final command = topCommand.key;
        
        print('🎯 Kết quả: $command (${(confidence * 100).toStringAsFixed(1)}%)');
        
        // Gọi callback với kết quả
        if (_onResultCallback != null) {
          _onResultCallback!({
            'type': 'cnn',
            'command': command,
            'confidence': confidence,
            'success': true,
          });
        }
      } else {
        print('❌ Không nhận diện được lệnh nói (độ tin cậy < 40%)');
        
        if (_onResultCallback != null) {
          _onResultCallback!({
            'type': 'cnn',
            'command': 'unknown',
            'confidence': 0.0,
            'success': false,
            'message': 'Không nhận diện được lệnh nói'
          });
        }
      }
    } catch (e) {
      print('❌ Lỗi xử lý audio: $e');
      
      if (_onResultCallback != null) {
        _onResultCallback!({
          'type': 'cnn', 
          'command': 'error',
          'confidence': 0.0,
          'success': false,
          'message': 'Lỗi xử lý: $e'
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  // Callback for results
  Function(Map<String, dynamic>)? _onResultCallback;
  
  void setOnResultCallback(Function(Map<String, dynamic>) callback) {
    _onResultCallback = callback;
  }

  // Play sound effects
  Future<void> _playSound(String soundType) async {
    try {
      if (soundType == 'voice_start') {
        await _audioPlayer.play(AssetSource('sounds/voice_start.mp3'));
      } else if (soundType == 'voice_stop') {
        await _audioPlayer.play(AssetSource('sounds/voice_stop.mp3'));
      } else if (soundType == 'switch_on') {
        await _audioPlayer.play(AssetSource('sounds/switch_on.mp3'));
      } else if (soundType == 'switch_off') {
        await _audioPlayer.play(AssetSource('sounds/switch_off.mp3'));
      }
    } catch (e) {
      print('Lỗi phát âm thanh: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _recordingTimer?.cancel();
    _classifier.dispose();
    _audioPlayer.dispose();
  }
}