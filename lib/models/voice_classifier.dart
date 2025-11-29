import 'dart:developer';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Lớp VoiceClassifier:  
/// - Tải và sử dụng model TensorFlow Lite để phân loại lệnh giọng nói
/// - Hỗ trợ phân loại lệnh dạng văn bản
/// - Cung cấp phương thức lấy lệnh có xác suất cao nhất
class VoiceClassifier {
  static const String modelFile = 'model.tflite';
  static const String labelFile = 'voice_labels.txt';

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelFile);
      _labels = await _loadLabelsFromAssets();
      _isLoaded = true;
      log('Đã tải model giọng nói thành công');
      log('Nhãn: $_labels');

      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();
      log('Input tensors: $inputTensors');
      log('Output tensors: $outputTensors');
    } catch (e) {
      log('Lỗi tải model giọng nói: $e');
      _isLoaded = false;
    }
  }

  Future<List<String>> _loadLabelsFromAssets() async {
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
      'bat_den_phong_ngu',
      'tat_den_phong_ngu'
    ];
  }

  List<List<double>> _preprocessAudio(List<double> audioData) {
    try {
      const int inputLength = 16000;
      List<List<double>> processedInput = [];
      List<double> processedAudio = List<double>.filled(inputLength, 0.0);
      int length = audioData.length < inputLength ? audioData.length : inputLength;

      for (int i = 0; i < length; i++) {
        processedAudio[i] = audioData[i];
      }

      processedInput.add(processedAudio);
      return processedInput;
    } catch (e) {
      log('Lỗi xử lý âm thanh: $e');
      return [List<double>.filled(16000, 0.0)];
    }
  }

  Map<String, double> classifyVoiceCommand(List<double> audioFeatures) {
    if (!_isLoaded) {
      log('Model chưa được tải');
      return {};
    }

    try {
      final input = _preprocessAudio(audioFeatures);
      var outputBuffer = List<double>.filled(_labels.length, 0.0);
      _interpreter.run(input, outputBuffer);

      log('Kết quả raw: $outputBuffer');

      final Map<String, double> labeledProb = {};
      for (int i = 0; i < outputBuffer.length && i < _labels.length; i++) {
        labeledProb[_labels[i]] = outputBuffer[i];
      }

      log('Kết quả phân loại: $labeledProb');
      return labeledProb;
    } catch (e) {
      log('Lỗi trong quá trình phân loại giọng nói: $e');
      return {};
    }
  }

  Map<String, double> classifyTextCommand(String textCommand) {
    final lowerCommand = textCommand.toLowerCase();
    Map<String, double> results = {};

    if (lowerCommand.contains('bật đèn phòng khách') ||
        lowerCommand.contains('mở đèn phòng khách')) {
      results['bat_den_phong_khach'] = 0.95;
    } else if (lowerCommand.contains('tắt đèn phòng khách') ||
        lowerCommand.contains('đóng đèn phòng khách')) {
      results['tat_den_phong_khach'] = 0.95;
    } else if (lowerCommand.contains('bật đèn phòng ngủ') ||
        lowerCommand.contains('mở đèn phòng ngủ')) {
      results['bat_den_phong_ngu'] = 0.95;
    } else if (lowerCommand.contains('tắt đèn phòng ngủ') ||
        lowerCommand.contains('đóng đèn phòng ngủ')) {
      results['tat_den_phong_ngu'] = 0.95;
    } else if (lowerCommand.contains('bật đèn') ||
        lowerCommand.contains('mở đèn')) {
      results['bat_den'] = 0.90;
    } else if (lowerCommand.contains('tắt đèn') ||
        lowerCommand.contains('đóng đèn')) {
      results['tat_den'] = 0.90;
    } else if (lowerCommand.contains('bật quạt') ||
        lowerCommand.contains('mở quạt')) {
      results['bat_quat'] = 0.85;
    } else if (lowerCommand.contains('tắt quạt') ||
        lowerCommand.contains('đóng quạt')) {
      results['tat_quat'] = 0.85;
    } else if (lowerCommand.contains('mở cửa') ||
        lowerCommand.contains('mở khóa cửa')) {
      results['mo_cua'] = 0.80;
    } else if (lowerCommand.contains('đóng cửa') ||
        lowerCommand.contains('khóa cửa')) {
      results['dong_cua'] = 0.80;
    } else if (lowerCommand.contains('bật tất cả') ||
        lowerCommand.contains('mở tất cả')) {
      results['bat_tat_ca'] = 0.75;
    } else if (lowerCommand.contains('tắt tất cả') ||
        lowerCommand.contains('đóng tất cả')) {
      results['tat_tat_ca'] = 0.75;
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