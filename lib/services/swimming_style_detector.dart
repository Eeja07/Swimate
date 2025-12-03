import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for detecting swimming style using TensorFlow Lite model
class SwimmingStyleDetector {
  static SwimmingStyleDetector? _instance;
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Supported swimming styles (order must match model output)
  // Model outputs 6 classes based on tensor shape [1, 6]
  static const List<String> styles = [
    'freestyle',
    'backstroke',
    'breaststroke',
    'butterfly',
    'notswimming',  // Class 5 - not swimming/rest
  ];

  // Hyperparameters for model inference
  static const int windowSize = 40; // Number of sensor samples for one prediction (model expects [1, 40, 6])
  static const int sensorFeatures = 6; // ax, ay, az, gx, gy, gz
  static const double confidenceThreshold = 0.6; // Minimum confidence to accept prediction

  SwimmingStyleDetector._();

  /// Get singleton instance
  static SwimmingStyleDetector get instance {
    _instance ??= SwimmingStyleDetector._();
    return _instance!;
  }

  /// Initialize and load the TFLite model
  Future<bool> loadModel() async {
    if (_isModelLoaded) return true;

    try {
      debugPrint('🤖 Loading swimming style detection model...');

      // Load the model from assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/swimming_style_model.tflite',
      );

      _isModelLoaded = true;
      debugPrint('✅ Model loaded successfully');
      
      // Print detailed tensor info
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      debugPrint('   Input tensor:');
      debugPrint('     - Shape: ${inputTensor.shape}');
      debugPrint('     - Type: ${inputTensor.type}');
      debugPrint('     - Name: ${inputTensor.name}');
      
      debugPrint('   Output tensor:');
      debugPrint('     - Shape: ${outputTensor.shape}');
      debugPrint('     - Type: ${outputTensor.type}');
      debugPrint('     - Name: ${outputTensor.name}');
      
      // Verify the number of output classes matches our style list
      final outputSize = outputTensor.shape[1];
      if (outputSize != styles.length) {
        debugPrint('⚠️ WARNING: Model output size ($outputSize) does not match styles list length (${styles.length})');
        debugPrint('   Please update the styles list to match the model output.');
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading model: $e');
      debugPrint('   Stack trace: $stackTrace');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Check if model is loaded and ready
  bool get isReady => _isModelLoaded && _interpreter != null;

  /// Detect swimming style from sensor data
  /// 
  /// [sensorData] should be a list of maps with keys: 'ax', 'ay', 'az', 'gx', 'gy', 'gz'
  /// Returns a map with 'style' and 'confidence', or null if detection fails
  Future<Map<String, dynamic>?> detectStyle(
    List<Map<String, dynamic>> sensorData,
  ) async {
    if (!isReady) {
      debugPrint('⚠️ Model not loaded');
      return null;
    }

    if (sensorData.length < windowSize) {
      debugPrint('⚠️ Not enough sensor data: ${sensorData.length} < $windowSize');
      return null;
    }

    try {
      debugPrint('📊 Preparing input from ${sensorData.length} samples...');
      
      // Prepare input data
      final input = _prepareInput(sensorData);
      
      debugPrint('📥 Input shape: ${input.length} x ${input[0].length} x ${input[0][0].length}');
      debugPrint('   First sample: ${input[0][0]}');
      debugPrint('   Last sample: ${input[0][input[0].length - 1]}');
      
      // Prepare output buffer
      final output = List.filled(styles.length, 0.0).reshape([1, styles.length]);

      debugPrint('🔄 Running inference...');
      debugPrint('   Output buffer initialized: ${output[0]}');
      
      // Run inference
      _interpreter!.run(input, output);

      debugPrint('📤 Inference complete');
      debugPrint('   Raw output: ${output[0]}');
      
      // Process output
      final probabilities = output[0] as List<double>;
      final maxIndex = _argMax(probabilities);
      final confidence = probabilities[maxIndex];
      final detectedStyle = styles[maxIndex];

      debugPrint('🏊 Style detected: $detectedStyle (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');
      debugPrint('   All probabilities: ${probabilities.map((p) => (p * 100).toStringAsFixed(1)).toList()}');

      // Enhanced detection logic with movement analysis
      String finalStyle;
      double finalConfidence;
      
      // Calculate movement intensity from recent samples
      final recentSamples = sensorData.length > 40 
          ? sensorData.sublist(sensorData.length - 40) 
          : sensorData;
      
      final accelMagnitudes = recentSamples.map((s) {
        final ax = s['ax'] ?? 0.0;
        final ay = s['ay'] ?? 0.0;
        final az = s['az'] ?? 0.0;
        return math.sqrt(ax * ax + ay * ay + az * az);
      }).toList();
      
      final avgMagnitude = accelMagnitudes.reduce((a, b) => a + b) / accelMagnitudes.length;
      final maxMagnitude = accelMagnitudes.reduce((a, b) => a > b ? a : b);
      
      // Calculate variance to detect movement patterns
      final mean = avgMagnitude;
      final variance = accelMagnitudes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / accelMagnitudes.length;
      final stdDev = math.sqrt(variance);
      
      debugPrint('   Movement analysis: avg=${avgMagnitude.toStringAsFixed(2)}, max=${maxMagnitude.toStringAsFixed(2)}, stdDev=${stdDev.toStringAsFixed(2)}');
      
      // Determine if movement indicates swimming activity
      // Low magnitude + low variance = likely not swimming or very gentle movement
      final isLowActivity = avgMagnitude < 12.0 && stdDev < 3.0 && maxMagnitude < 15.0;
      
      // If all swimming styles have low confidence AND low activity detected
      final maxSwimmingProb = probabilities.sublist(0, 4).reduce((a, b) => a > b ? a : b);
      
      if (isLowActivity && maxSwimmingProb < 0.5) {
        // Movement pattern suggests not swimming or resting
        finalStyle = 'notswimming';
        finalConfidence = 1.0 - maxSwimmingProb; // Inverse of swimming confidence
        debugPrint('   🛑 Low activity detected, overriding to notswimming (activity score: ${(finalConfidence * 100).toStringAsFixed(1)}%)');
      } else if (detectedStyle == 'notswimming' || detectedStyle == 'unknown') {
        // Model detected notswimming/unknown but activity is present
        // Find best swimming style (first 4 classes)
        final swimmingProbs = probabilities.sublist(0, 4);
        final bestSwimmingIndex = _argMax(swimmingProbs);
        finalStyle = styles[bestSwimmingIndex];
        finalConfidence = swimmingProbs[bestSwimmingIndex];
        
        debugPrint('   Detected as $detectedStyle but activity present, using best swimming style: $finalStyle (${(finalConfidence * 100).toStringAsFixed(1)}%)');
      } else {
        // Model is confident about a swimming style
        finalStyle = detectedStyle;
        finalConfidence = confidence;
      }

      // Always return a result
      return {
        'style': finalStyle,  // Always return the style, even if confidence is low
        'confidence': finalConfidence,
        'probabilities': {
          for (var i = 0; i < styles.length; i++) styles[i]: probabilities[i],
        },
        'raw_style': detectedStyle,  // Keep original detection for debugging
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error during inference: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Prepare input tensor from sensor data
  List<List<List<double>>> _prepareInput(List<Map<String, dynamic>> sensorData) {
    // Take the last 'windowSize' samples
    final samples = sensorData.length > windowSize
        ? sensorData.sublist(sensorData.length - windowSize)
        : sensorData;

    debugPrint('   Using samples from index ${sensorData.length - samples.length} to ${sensorData.length - 1}');

    // Normalize and structure data for model
    final normalizedData = <List<double>>[];

    for (var sample in samples) {
      normalizedData.add([
        _normalize(sample['ax'] ?? 0.0, -20.0, 20.0),
        _normalize(sample['ay'] ?? 0.0, -20.0, 20.0),
        _normalize(sample['az'] ?? 0.0, -20.0, 20.0),
        _normalize(sample['gx'] ?? 0.0, -10.0, 10.0),
        _normalize(sample['gy'] ?? 0.0, -10.0, 10.0),
        _normalize(sample['gz'] ?? 0.0, -10.0, 10.0),
      ]);
    }

    // Pad with zeros if needed
    while (normalizedData.length < windowSize) {
      normalizedData.insert(0, List.filled(sensorFeatures, 0.0));
    }

    return [normalizedData];
  }

  /// Normalize value to range [0, 1]
  double _normalize(double value, double min, double max) {
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// Find index of maximum value in list
  int _argMax(List<double> list) {
    double maxValue = list[0];
    int maxIndex = 0;

    for (int i = 1; i < list.length; i++) {
      if (list[i] > maxValue) {
        maxValue = list[i];
        maxIndex = i;
      }
    }

    return maxIndex;
  }

  /// Detect style from continuous stream with smoothing
  /// This is useful for real-time detection during swimming
  Future<Map<String, dynamic>?> detectStyleSmooth(
    List<Map<String, dynamic>> sensorData, {
    int numPredictions = 1,
  }) async {
    debugPrint('🎯 detectStyleSmooth called with ${sensorData.length} samples');
    
    // Just use the most recent data for now - simpler and more reliable
    if (sensorData.length < windowSize) {
      debugPrint('⚠️ Not enough data for smooth detection: ${sensorData.length} < $windowSize');
      return null;
    }

    // Make a single prediction with the most recent data
    final result = await detectStyle(sensorData);
    debugPrint('🎯 detectStyleSmooth returning: $result');
    return result;
  }

  /// Calculate features from sensor data for analysis
  Map<String, double> calculateFeatures(List<Map<String, dynamic>> sensorData) {
    if (sensorData.isEmpty) {
      return {
        'mean_accel': 0.0,
        'std_accel': 0.0,
        'mean_gyro': 0.0,
        'std_gyro': 0.0,
      };
    }

    final accelMagnitudes = <double>[];
    final gyroMagnitudes = <double>[];

    for (var sample in sensorData) {
      final ax = sample['ax'] ?? 0.0;
      final ay = sample['ay'] ?? 0.0;
      final az = sample['az'] ?? 0.0;
      final gx = sample['gx'] ?? 0.0;
      final gy = sample['gy'] ?? 0.0;
      final gz = sample['gz'] ?? 0.0;

      accelMagnitudes.add(math.sqrt(ax * ax + ay * ay + az * az));
      gyroMagnitudes.add(math.sqrt(gx * gx + gy * gy + gz * gz));
    }

    return {
      'mean_accel': _mean(accelMagnitudes),
      'std_accel': _std(accelMagnitudes),
      'mean_gyro': _mean(gyroMagnitudes),
      'std_gyro': _std(gyroMagnitudes),
    };
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _std(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = _mean(values);
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }

  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    debugPrint('🧹 Model resources cleaned up');
  }
}
