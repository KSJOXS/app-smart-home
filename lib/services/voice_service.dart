import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import '../models/voice_classifier.dart';

class VoiceService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final VoiceClassifier _voiceClassifier = VoiceClassifier();

  bool _isSpeechEnabled = false;
  bool _isListening = false;
  bool _isModelLoaded = false;
  bool _useTFLite = true;

  bool get isListening => _isListening;
  bool get isSpeechEnabled => _isSpeechEnabled;
  bool get isModelLoaded => _isModelLoaded;

  // Initialize speech recognition
  Future<void> initializeSpeech() async {
    try {
      _isSpeechEnabled = await _speechToText.initialize();
    } catch (e) {
      _isSpeechEnabled = false;
    }
  }

  // Load TFLite model
  Future<void> loadModel() async {
    try {
      await _voiceClassifier.loadModel();
      _isModelLoaded = _voiceClassifier.isLoaded;
      if (!_isModelLoaded) {
        _useTFLite = false;
      }
    } catch (e) {
      _isModelLoaded = false;
      _useTFLite = false;
    }
  }

  // Start listening
  Future<void> startListening(
      Function(String) onResult, Function(String) onError) async {
    if (!_isSpeechEnabled) {
      onError('Speech recognition not available');
      return;
    }

    try {
      _isListening = true;

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 10),
      );
    } catch (e) {
      onError('Listening error');
      _isListening = false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (e) {
      _isListening = false;
    }
  }

  // Play sound
  Future<void> playSound(String soundType) async {
    try {
      String soundPath;
      switch (soundType) {
        case 'switch_on':
          soundPath = 'sounds/switch_on.mp3';
          break;
        case 'switch_off':
          soundPath = 'sounds/switch_off.mp3';
          break;
        case 'voice_start':
          soundPath = 'sounds/voice_start.mp3';
          break;
        case 'voice_stop':
          soundPath = 'sounds/voice_stop.mp3';
          break;
        case 'camera_start':
          soundPath = 'sounds/camera_start.mp3';
          break;
        default:
          soundPath = 'sounds/switch_on.mp3';
      }

      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      // Silent error
    }
  }

  // Classify voice command
  MapEntry<String, double>? classifyCommand(String command) {
    if (_isModelLoaded && _useTFLite) {
      return _voiceClassifier.getTopCommandFromText(command);
    }
    return null;
  }

  // Dispose resources
  void dispose() {
    _voiceClassifier.dispose();
    _audioPlayer.dispose();
  }
}
