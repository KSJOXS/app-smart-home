// import 'dart:io';

// import 'package:tflite_flutter/tflite_flutter.dart';

// class TextClassifier {
//   late Interpreter _interpreter;
//   final String _modelPath = 'assets/text_model.tflite';
//   final List<String> _labels = ['turn_on_light', 'turn_off_light', ...]; // your labels

//   Future<void> loadModel() async {
//     try {
//       _interpreter = await Interpreter.fromAsset(_modelPath);
//     } catch (e) {
//       print('Failed to load model: $e');
//     }
//   }

//   String classify(String text) {
//     // Preprocess the text: convert to sequence of integers, pad, etc.
//     var input = _preprocess(text);
//     var output = List.filled(1, 0).reshape([1, _labels.length]);
//     _interpreter.run(input, output);
//     // Postprocess: get the index of the highest score
//     int index = _argmax(output[0]);
//     return _labels[index];
//   }

//   List<List<int>> _preprocess(String text) {
//     // TODO: Implement the preprocessing steps that your model expects.
//     // This might include tokenization, converting to integers, padding, etc.
//     // Example: return a list of integers of fixed length (e.g., 128) for the model input.
//     // This is just a placeholder.
//     return [List.filled(128, 0)];
//   }

//   int _argmax(List<double> list) {
//     int index = 0;
//     double max = list[0];
//     for (int i = 1; i < list.length; i++) {
//       if (list[i] > max) {
//         index = i;
//         max = list[i];
//       }
//     }
//     return index;
//   }

//   void dispose() {
//     _interpreter.close();
//   }
// }
