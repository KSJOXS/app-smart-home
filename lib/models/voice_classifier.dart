import 'package:tflite_flutter/tflite_flutter.dart';

class VoiceClassifier {
  static const String modelFile = 'model.tflite';
  
  late Interpreter _interpreter;
  bool _isLoaded = false;
  
  // Các lớp theo model train của bạn
  final List<String> _labels = [
    'bat_quat',
    'tat_quat', 
    'bat_tat_ca',
    'tat_tat_ca',
    'bat_den_phong_khach',
    'tat_den_phong_khach',
    'bat_den_phong_ngu',
    'tat_den_phong_ngu',
    'bat_den_phong_bep',
    'tat_den_phong_bep',
  ];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelFile);
      
      // Debug model info
      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();
      print('Input tensors: $inputTensors');
      print('Output tensors: $outputTensors');
      
      _isLoaded = true;
      print('✅ Đã tải model CNN thành công với ${_labels.length} lớp');
    } catch (e) {
      print('❌ Lỗi tải model: $e');
      _isLoaded = false;
    }
  }

  // Xử lý audio features từ ghi âm
  List<List<List<List<double>>>> _preprocessAudioFeatures(List<double> audioData) {
    try {
      // Giả lập dữ liệu mel-spectrogram đầu vào
      // THAY THẾ PHẦN NÀY BẰNG XỬ LÝ THẬT TỪ AUDIO RECORDING
      const int nMels = 64;
      const int timeFrames = 128;
      const int channels = 2;
      
      List<List<List<List<double>>>> processedInput = [];
      List<List<List<double>>> melData = [];
      
      // Tạo dữ liệu mel-spectrogram giả lập
      for (int i = 0; i < nMels; i++) {
        List<List<double>> timeData = [];
        for (int j = 0; j < timeFrames; j++) {
          List<double> channelData = [];
          for (int k = 0; k < channels; k++) {
            // Sử dụng audioData nếu có, nếu không dùng giá trị mặc định
            double value = audioData.isNotEmpty 
                ? audioData[(i * timeFrames + j) % audioData.length] 
                : 0.0;
            channelData.add(value);
          }
          timeData.add(channelData);
        }
        melData.add(timeData);
      }
      
      processedInput.add(melData);
      return processedInput;
    } catch (e) {
      print('Lỗi xử lý audio features: $e');
      return _createEmptyInput();
    }
  }

  List<List<List<List<double>>>> _createEmptyInput() {
    const int nMels = 64;
    const int timeFrames = 128;
    const int channels = 2;
    
    List<List<List<List<double>>>> emptyInput = [];
    List<List<List<double>>> melData = [];
    
    for (int i = 0; i < nMels; i++) {
      List<List<double>> timeData = [];
      for (int j = 0; j < timeFrames; j++) {
        List<double> channelData = List<double>.filled(channels, 0.0);
        timeData.add(channelData);
      }
      melData.add(timeData);
    }
    
    emptyInput.add(melData);
    return emptyInput;
  }

  // Dự đoán từ audio features
  Map<String, double> predictCommand(List<double> audioFeatures) {
    if (!_isLoaded) {
      print('Model chưa được tải');
      return {};
    }

    try {
      // Xử lý đầu vào
      final input = _preprocessAudioFeatures(audioFeatures);
      
      // Chuẩn bị bộ đệm đầu ra
      var outputBuffer = List<double>.filled(_labels.length, 0.0);
      
      // Chạy suy luận
      _interpreter.run(input, outputBuffer);
      
      print('Kết quả raw: $outputBuffer');
      
      // Xử lý kết quả
      final Map<String, double> predictions = {};
      double maxConfidence = 0.0;
      String topCommand = '';
      
      for (int i = 0; i < outputBuffer.length && i < _labels.length; i++) {
        double confidence = outputBuffer[i];
        predictions[_labels[i]] = confidence;
        
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          topCommand = _labels[i];
        }
      }
      
      print('Dự đoán: $topCommand với độ tin cậy: ${(maxConfidence * 100).toStringAsFixed(1)}%');
      
      return predictions;
    } catch (e) {
      print('Lỗi trong quá trình dự đoán: $e');
      return {};
    }
  }

  // Lấy lệnh có độ tin cậy cao nhất
  MapEntry<String, double>? getTopCommand(List<double> audioFeatures) {
    final predictions = predictCommand(audioFeatures);
    return _getTopPrediction(predictions);
  }

  MapEntry<String, double>? _getTopPrediction(Map<String, double> predictions) {
    if (predictions.isEmpty) return null;
    
    var topEntry = predictions.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    // Chỉ chấp nhận nếu độ tin cậy > 40%
    return topEntry.value > 0.4 ? topEntry : null;
  }

  bool get isLoaded => _isLoaded;

  void dispose() {
    _interpreter.close();
  }
}