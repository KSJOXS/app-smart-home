import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/voice_classifier.dart';

class VoiceService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final VoiceClassifier _classifier = VoiceClassifier();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isModelLoaded = false;
  bool _useTFLite = true;

  // Getters
  bool get isListening => _isListening;
  bool get isModelLoaded => _isModelLoaded;
  bool get useTFLite => _useTFLite;
  bool get speechEnabled => _speechEnabled;

  // Initialize speech recognition
  Future<void> initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
  }

  // Load TFLite model
  Future<void> loadModel() async {
    try {
      await _classifier.loadModel();
      _isModelLoaded = _classifier.isLoaded;
    } catch (e) {
      debugPrint('Lỗi tải model TFLite: $e');
      _isModelLoaded = false;
      _useTFLite = false;
    }
  }

  // Start listening
  Future<void> startListening(Function(String) onResult) async {
    if (!_speechEnabled) return;

    _isListening = true;
    await _playSound('voice_start');

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 10),
    );
  }

  // Stop listening
  Future<void> stopListening() async {
    await _speechToText.stop();
    await _playSound('voice_stop');
    _isListening = false;
  }

  // Process voice command with TFLite
  Future<Map<String, dynamic>> processVoiceCommand(String command) async {
    debugPrint('Lệnh giọng nói: "$command"');

    if (_isModelLoaded && _useTFLite) {
      final topCommand = _classifier.getTopCommandFromText(command);
      if (topCommand != null) {
        return {
          'type': 'ai',
          'command': topCommand.key,
          'confidence': topCommand.value,
          'original': command,
        };
      }
    }

    // Fallback to traditional processing
    return {
      'type': 'traditional',
      'command': _parseTraditionalCommand(command),
      'original': command,
    };
  }

  // Traditional command parsing
  String _parseTraditionalCommand(String command) {
    final lowerCommand = command.toLowerCase();

    if (lowerCommand.contains('mở cửa') || lowerCommand.contains('mở khóa cửa')) {
      return 'mo_cua';
    } else if (lowerCommand.contains('đóng cửa') || lowerCommand.contains('khóa cửa')) {
      return 'dong_cua';
    } else if (lowerCommand.contains('bật đèn phòng khách') || lowerCommand.contains('mở đèn phòng khách')) {
      return 'bat_den_phong_khach';
    } else if (lowerCommand.contains('tắt đèn phòng khách') || lowerCommand.contains('đóng đèn phòng khách')) {
      return 'tat_den_phong_khach';
    } else if (lowerCommand.contains('bật đèn phòng ngủ') || lowerCommand.contains('mở đèn phòng ngủ')) {
      return 'bat_den_phong_ngu';
    } else if (lowerCommand.contains('tắt đèn phòng ngủ') || lowerCommand.contains('đóng đèn phòng ngủ')) {
      return 'tat_den_phong_ngu';
    } else if (lowerCommand.contains('bật đèn') || lowerCommand.contains('mở đèn')) {
      return 'bat_den';
    } else if (lowerCommand.contains('tắt đèn') || lowerCommand.contains('đóng đèn')) {
      return 'tat_den';
    } else if (lowerCommand.contains('bật quạt') || lowerCommand.contains('mở quạt')) {
      return 'bat_quat';
    } else if (lowerCommand.contains('tắt quạt') || lowerCommand.contains('đóng quạt')) {
      return 'tat_quat';
    } else if (lowerCommand.contains('bật tất cả đèn') || lowerCommand.contains('mở tất cả đèn')) {
      return 'bat_tat_ca';
    } else if (lowerCommand.contains('tắt tất cả đèn') || lowerCommand.contains('đóng tất cả đèn')) {
      return 'tat_tat_ca';
    } else if (lowerCommand.contains('mở camera') || lowerCommand.contains('bật camera')) {
      return 'mo_camera';
    } else if (lowerCommand.contains('đóng camera') || lowerCommand.contains('tắt camera')) {
      return 'dong_camera';
    }

    return 'unknown';
  }

  // Play sound effects
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

  // Toggle TFLite mode
  void toggleTFLiteMode(bool value) {
    _useTFLite = value && _isModelLoaded;
  }

  // Dispose resources
  void dispose() {
    _classifier.dispose();
    _audioPlayer.dispose();
  }
}