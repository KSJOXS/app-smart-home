import 'package:tflite_flutter/tflite_flutter.dart';

class VoiceClassifier {
  static const String modelFile = 'assets/models/model.tflite';

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      // Load model
      _interpreter = await Interpreter.fromAsset(modelFile);

      // Initialize labels - updated with new labels
      _labels = [
        'bat_quat',
        'tat_quat',
        'bat_tat_ca',
        'tat_tat_ca',
        'bat_den_phong_khach',
        'tat_den_phong_khach',
        'bat_den_phong_ngu',
        'tat_den_phong_ngu',
        'tat_den_phong_bep',
        'bat_den_phong_bep',
      ];

      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
    }
  }

  // Classify voice command from audio features
  Map<String, double> classifyVoiceCommand(List<double> audioFeatures) {
    if (!_isLoaded) {
      return {};
    }

    try {
      // Preprocess audio
      final input = _preprocessAudio(audioFeatures);

      // Prepare output buffer
      var outputBuffer = List<double>.filled(_labels.length, 0.0);

      // Run inference
      _interpreter.run(input, outputBuffer);

      // Process results
      final Map<String, double> labeledProb = {};

      for (int i = 0; i < outputBuffer.length && i < _labels.length; i++) {
        labeledProb[_labels[i]] = outputBuffer[i];
      }

      return labeledProb;
    } catch (e) {
      return {};
    }
  }

  // Classify from text command (fallback)
  Map<String, double> classifyTextCommand(String textCommand) {
    final lowerCommand = textCommand.toLowerCase();
    Map<String, double> results = {};

    // Match keywords with confidence scores
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

  // Audio preprocessing
  List<List<double>> _preprocessAudio(List<double> audioData) {
    try {
      const int inputLength = 16000; // Default for speech models

      // Create 2D array with appropriate shape for model
      List<List<double>> processedInput = [];

      // Simple processing - pad or truncate to expected length
      List<double> processedAudio = List<double>.filled(inputLength, 0.0);
      int length =
          audioData.length < inputLength ? audioData.length : inputLength;

      for (int i = 0; i < length; i++) {
        processedAudio[i] = audioData[i];
      }

      // Reshape for model input
      processedInput.add(processedAudio);

      return processedInput;
    } catch (e) {
      return [List<double>.filled(16000, 0.0)];
    }
  }
}
