import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:async';

// Phân loại giọng nói TFLite - UPDATED TO IGNORE DOOR COMMANDS
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
      print('Đã tải model giọng nói thành công');
      print('Nhãn: $_labels');

      // Debug model info
      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();
      print('Input tensors: $inputTensors');
      print('Output tensors: $outputTensors');
    } catch (e) {
      print('Lỗi tải model giọng nói: $e');
      _isLoaded = false;
    }
  }

  Future<List<String>> _loadLabelsFromAssets() async {
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
      'bat_den_phong_bep',
    ];
  }

  // Xử lý trước âm thanh - SIMPLIFIED VERSION
  List<List<double>> _preprocessAudio(List<double> audioData) {
    try {
      const int inputLength = 16000;

      List<List<double>> processedInput = [];
      List<double> processedAudio = List<double>.filled(inputLength, 0.0);
      int length =
          audioData.length < inputLength ? audioData.length : inputLength;

      for (int i = 0; i < length; i++) {
        processedAudio[i] = audioData[i];
      }

      processedInput.add(processedAudio);
      return processedInput;
    } catch (e) {
      print('Lỗi xử lý âm thanh: $e');
      return [List<double>.filled(16000, 0.0)];
    }
  }

  // Phân loại lệnh giọng nói từ đặc trưng âm thanh
  Map<String, double> classifyVoiceCommand(List<double> audioFeatures) {
    if (!_isLoaded) {
      print('Model chưa được tải');
      return {};
    }

    try {
      final input = _preprocessAudio(audioFeatures);
      var outputBuffer = List<double>.filled(_labels.length, 0.0);

      _interpreter.run(input, outputBuffer);
      print('Kết quả raw: $outputBuffer');

      final Map<String, double> labeledProb = {};
      for (int i = 0; i < outputBuffer.length && i < _labels.length; i++) {
        labeledProb[_labels[i]] = outputBuffer[i];
      }

      print('Kết quả phân loại: $labeledProb');
      return labeledProb;
    } catch (e) {
      print('Lỗi trong quá trình phân loại giọng nói: $e');
      return {};
    }
  }

  // Phân loại từ lệnh văn bản (dự phòng) - UPDATED TO IGNORE "CỬA"
  Map<String, double> classifyTextCommand(String textCommand) {
    final lowerCommand = textCommand.toLowerCase();

    // NEW: If command contains "cửa" (door), stop processing to avoid wrong triggers
    if (lowerCommand.contains('cửa')) {
      print('Lệnh liên quan đến cửa bị từ chối.');
      return {};
    }

    Map<String, double> results = {};

    if (lowerCommand.contains('bật quạt') || lowerCommand.contains('mở quạt')) {
      results['bat_quat'] = 0.95;
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt')) {
      results['tat_quat'] = 0.95;
    } else if (lowerCommand.contains('bật tất cả') ||
        lowerCommand.contains('mở tất cả')) {
      results['bat_tat_ca'] = 0.90;
    } else if (lowerCommand.contains('tắt tất cả') ||
        lowerCommand.contains('đóng tất cả')) {
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
        lowerCommand.contains('mở đèn phòng bếp')) {
      results['bat_den_phong_bep'] = 0.85;
    } else if (lowerCommand.contains('tắt đèn phòng bếp') ||
        lowerCommand.contains('đóng đèn phòng bếp')) {
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

  // Updated to 0.75 confidence to ignore ambient noise like door opening/closing sounds
  MapEntry<String, double>? _getTopResult(Map<String, double> results) {
    if (results.isEmpty) return null;

    var topEntry = results.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Filter by higher threshold to avoid False Positives
    return topEntry.value > 0.75 ? topEntry : null;
  }

  bool get isLoaded => _isLoaded;

  void dispose() {
    _interpreter.close();
  }
}
