import 'package:flutter/material.dart';
import '../widgets/floating_bottom_bar.dart';
import '../widgets/custom_navbar.dart';
import 'dart:async';
import 'confirm_activity.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../widgets/wave_background.dart';
import '../services/swimming_style_detector.dart';

// --- Konstanta Warna Tema ---
const Color primaryColor = Color(0xFF1976D2);
const Color accentColor = Color(0xFF4FC3F7);
const Color lightTextColor = Colors.white;
const Color darkBgColor = Colors.black;
const Color warningColor = Color(0xFFFF5500);

// ==================== RESPONSIVE HELPERS ====================
class AppBreakpoints {
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
}

T responsive<T>({
  required BuildContext context,
  required T sm,
  T? md,
  T? lg,
  T? xl,
}) {
  final width = MediaQuery.of(context).size.width;
  if (xl != null && width >= AppBreakpoints.xl) return xl;
  if (lg != null && width >= AppBreakpoints.lg) return lg;
  if (md != null && width >= AppBreakpoints.md) return md;
  return sm;
}

// ==================== RecordPage ====================
class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with TickerProviderStateMixin {
  // ==================== STATE VARIABLES ====================

  bool isRecording = false;
  bool isPaused = false;
  int seconds = 0;

  int strokes = 0;
  double distance = 0.0;

  Timer? _mainTimer;
  Timer? _sensorTimer;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  AccelerometerEvent? _lastAccelEvent;
  GyroscopeEvent? _lastGyroEvent;
  final List<Map<String, dynamic>> _sensorSamples = [];

  double _lastAccelMagnitude = 0.0;
  int _lastStrokeTimestamp = 0;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String _currentDetectedStyle = 'Detecting...';
  double _styleConfidence = 0.0;
  String _previousDetectedStyle = '';
  int _styleChangeCount = 0;
  Timer? _styleDetectionTimer;
  final _styleDetector = SwimmingStyleDetector.instance;
  bool _isModelReady = false;

  // ==================== SEGMENT TRACKING ====================
  final List<Map<String, dynamic>> _segments = [];
  int _currentSegmentStartTime = 0; // dalam detik
  String _currentSegmentStyle = '';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeMLModel();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  void _initializeAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuad,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  void _initializeMLModel() async {
    debugPrint('🤖 Initializing ML model...');
    final success = await _styleDetector.loadModel();
    if (mounted) {
      setState(() {
        _isModelReady = success;
      });
    }
    if (success) {
      debugPrint('✅ ML model ready');
    } else {
      debugPrint('❌ Failed to load ML model');
    }
  }

  void _disposeResources() {
    _animController.dispose();
    _mainTimer?.cancel();
    _sensorTimer?.cancel();
    _styleDetectionTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();
  }

  Future<void> _updateGpsStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      String newStatus = 'Unknown';

      if (!serviceEnabled) {
        newStatus = 'Disabled';
      } else if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        newStatus = 'Denied';
      } else if (_lastPosition == null) {
        newStatus = 'Searching';
      } else {
        newStatus = 'Locked';
      }

      debugPrint('GPS Status: $newStatus');
    } catch (e) {
      debugPrint('Error checking GPS status: $e');
    }
  }

  // ==================== SEGMENT MANAGEMENT ====================
  
  void _startNewSegment(String style) {
    _currentSegmentStartTime = seconds;
    _currentSegmentStyle = style;
    debugPrint('📍 Started new segment: $style at ${seconds}s');
  }

  void _finalizeCurrentSegment() {
    if (_currentSegmentStyle.isEmpty) return;
    
    final duration = seconds - _currentSegmentStartTime;
    
    // Hanya simpan segment jika durasinya > 0
    if (duration > 0) {
      _segments.add({
        'style': _currentSegmentStyle,
        'duration': duration,
        'startTime': _currentSegmentStartTime,
        'endTime': seconds,
      });
      
      debugPrint('✅ Finalized segment: $_currentSegmentStyle, duration: ${duration}s (${_currentSegmentStartTime}s - ${seconds}s)');
    }
  }

  void _handleStyleChange(String newStyle) {
    // Jika ini adalah deteksi pertama
    if (_currentSegmentStyle.isEmpty) {
      _startNewSegment(newStyle);
      return;
    }

    // Jika style berubah
    if (newStyle != _currentSegmentStyle) {
      // Finalisasi segment sebelumnya
      _finalizeCurrentSegment();
      
      // Mulai segment baru
      _startNewSegment(newStyle);
      
      _styleChangeCount++;
      debugPrint('🔄 Style changed: $_currentSegmentStyle → $newStyle (change #$_styleChangeCount)');
    }
  }

  // ==================== RECORDING CONTROLS ====================

  void _startRecording() {
    setState(() {
      isRecording = true;
      isPaused = false;
      _styleChangeCount = 0;
      _previousDetectedStyle = '';
      _segments.clear();
      _currentSegmentStyle = '';
      _currentSegmentStartTime = 0;
    });

    _startMainTimer();
    _startSensorTracking();
    _startGpsTracking();
    _startStyleDetection();
  }

  void _pauseRecording() {
    setState(() => isPaused = true);

    _mainTimer?.cancel();
    _sensorTimer?.cancel();
    _styleDetectionTimer?.cancel();
    _accelSubscription?.pause();
    _gyroSubscription?.pause();
    _positionSubscription?.pause();
  }

  void _resumeRecording() {
    setState(() => isPaused = false);

    _startMainTimer();
    _startSensorSampling();
    _startStyleDetection();
    _accelSubscription?.resume();
    _gyroSubscription?.resume();
    _positionSubscription?.resume();
  }

  void _stopRecording() {
    // Finalisasi segment terakhir sebelum stop
    _finalizeCurrentSegment();

    final recordedSeconds = seconds;
    final recordedDistance = distance;
    final recordedStrokes = strokes;
    final recordedSensors = List<Map<String, dynamic>>.from(_sensorSamples);
    final detectedStyle = _currentDetectedStyle;
    final styleConfidence = _styleConfidence;
    final recordedSegments = List<Map<String, dynamic>>.from(_segments);

    debugPrint('🛑 Stopping recording with ${recordedSegments.length} segments:');
    for (var i = 0; i < recordedSegments.length; i++) {
      final seg = recordedSegments[i];
      debugPrint('   Segment ${i + 1}: ${seg['style']} - ${seg['duration']}s (${seg['startTime']}s - ${seg['endTime']}s)');
    }

    _mainTimer?.cancel();
    _sensorTimer?.cancel();
    _styleDetectionTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();

    setState(() {
      isRecording = false;
      isPaused = false;
      seconds = 0;
      strokes = 0;
      distance = 0.0;
      _sensorSamples.clear();
      _lastPosition = null;
      _currentDetectedStyle = 'Detecting...';
      _styleConfidence = 0.0;
      _segments.clear();
      _currentSegmentStyle = '';
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmActivityPage(
            durationSeconds: recordedSeconds,
            distance: recordedDistance,
            strokes: recordedStrokes,
            sensorData: recordedSensors,
            segments: recordedSegments.isNotEmpty ? recordedSegments : null,
            detectedStyle: detectedStyle,
            styleConfidence: styleConfidence,
          ),
        ),
      );
    }
  }

  void _startMainTimer() {
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          seconds++;
          if (_lastPosition == null) {
            distance += 0.5;
          }
        });
      }
    });
  }

  void _startSensorTracking() {
    _sensorSamples.clear();

    _accelSubscription = accelerometerEventStream().listen((event) {
      _lastAccelEvent = event;
    });

    _gyroSubscription = gyroscopeEventStream().listen((event) {
      _lastGyroEvent = event;
    });

    _startSensorSampling();
  }

  void _startSensorSampling() {
    const samplingInterval = Duration(milliseconds: 50);
    const strokeThreshold = 18.4;
    const strokeDebounceMs = 600;

    _sensorTimer = Timer.periodic(samplingInterval, (_) {
      final now = DateTime.now().millisecondsSinceEpoch;

      final ax = _lastAccelEvent?.x ?? 0.0;
      final ay = _lastAccelEvent?.y ?? 0.0;
      final az = _lastAccelEvent?.z ?? 0.0;
      final gx = _lastGyroEvent?.x ?? 0.0;
      final gy = _lastGyroEvent?.y ?? 0.0;
      final gz = _lastGyroEvent?.z ?? 0.0;

      final magnitude = math.sqrt(ax * ax + ay * ay + az * az);

      if (_isStrokeDetected(magnitude, now, strokeThreshold, strokeDebounceMs)) {
        strokes++;
        _lastStrokeTimestamp = now;
      }

      _lastAccelMagnitude = magnitude;

      _sensorSamples.add({
        't': now,
        'ax': ax,
        'ay': ay,
        'az': az,
        'gx': gx,
        'gy': gy,
        'gz': gz,
      });
    });
  }

  bool _isStrokeDetected(double magnitude, int now, double threshold, int debounceMs) {
    return magnitude > threshold &&
        _lastAccelMagnitude <= threshold &&
        (now - _lastStrokeTimestamp) > debounceMs;
  }

  void _startStyleDetection() {
    if (!_isModelReady) {
      debugPrint('⚠️ Cannot start style detection: model not ready');
      return;
    }

    debugPrint('🏁 Starting continuous style detection');

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (isRecording && !isPaused && mounted) {
        debugPrint('⏰ First detection triggered');
        _detectStyleOnce();
      }
    });

    _styleDetectionTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!isPaused && mounted && isRecording) {
        debugPrint('⏰ Continuous detection triggered');
        _detectStyleOnce();
      }
    });
  }

  void _detectStyleOnce() async {
    if (!mounted || !isRecording) return;
    
    final totalSamples = _sensorSamples.length;
    
    if (totalSamples >= SwimmingStyleDetector.windowSize) {
      final startTime = DateTime.now();
      debugPrint('🔍 Detection #${_styleChangeCount + 1} - Processing last 40 of $totalSamples total samples');
      
      try {
        final result = await _styleDetector.detectStyleSmooth(_sensorSamples);
        
        final inferenceTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('📦 Detection completed in ${inferenceTime}ms');
        
        if (result != null && mounted) {
          final style = result['style'] as String;
          final confidence = result['confidence'] as double;
          
          // Handle segment tracking berdasarkan perubahan style
          _handleStyleChange(style);
          
          _previousDetectedStyle = style;
          
          setState(() {
            _currentDetectedStyle = style;
            _styleConfidence = confidence;
          });
          
          debugPrint('✅ Updated: $_currentDetectedStyle (${(_styleConfidence * 100).toStringAsFixed(1)}%)');
          
          if (result.containsKey('probabilities')) {
            final probs = result['probabilities'] as Map<String, dynamic>;
            final sortedProbs = probs.entries.toList()
              ..sort((a, b) => (b.value as double).compareTo(a.value as double));
            debugPrint('   Top 3 predictions:');
            for (var i = 0; i < 3 && i < sortedProbs.length; i++) {
              debugPrint('     ${i + 1}. ${sortedProbs[i].key}: ${(sortedProbs[i].value * 100).toStringAsFixed(1)}%');
            }
          }
        } else {
          debugPrint('⚠️ Detection returned null or widget not mounted');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Error in detection: $e');
        debugPrint('   Stack: $stackTrace');
      }
    } else {
      debugPrint('⏳ Collecting data: $totalSamples/${SwimmingStyleDetector.windowSize} samples');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _startGpsTracking() {
    Future.microtask(() async {
      await _updateGpsStatus();

      try {
        final permission = await _requestLocationPermission();
        if (permission == null) return;

        await _seedInitialPosition();
        _startPositionStream();
      } catch (e) {
        debugPrint('Geolocator error: $e');
      }
    });
  }

  Future<LocationPermission?> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return null;
    }

    return permission;
  }

  Future<void> _seedInitialPosition() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      _lastPosition = position;
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }
  }

  void _startPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _updateDistance(position);
      _lastPosition = position;
    });
  }

  void _updateDistance(Position newPosition) {
    if (_lastPosition == null) return;

    final distanceDelta = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    if (distanceDelta.isFinite && distanceDelta > 0) {
      if (mounted) {
        setState(() => distance += distanceDelta);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: const CustomNavbar(title: "Record"),
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return WaveBackground(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildBody(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final topPadding = responsive(
      context: context,
      sm: 24.0,
      md: 30.0,
      lg: 40.0,
      xl: 48.0,
    );

    final betweenLargeSections = responsive(
      context: context,
      sm: 20.0,
      md: 30.0,
      lg: 40.0,
    );

    final bottomExtra = responsive(
      context: context,
      sm: 10.0,
      md: 16.0,
      lg: 24.0,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive(context: context, sm: 12, md: 16, lg: 24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: topPadding),
          _buildStopwatch(context),
          SizedBox(height: betweenLargeSections),
          if (isRecording) _buildStyleIndicator(),
          if (isRecording) SizedBox(height: betweenLargeSections / 2),
          _buildMetrics(),
          SizedBox(height: betweenLargeSections),
          _buildActionButton(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + bottomExtra),
        ],
      ),
    );
  }

  Widget _buildStyleIndicator() {
    final styleIcon = _getStyleIcon(_currentDetectedStyle);
    final confidencePercent = (_styleConfidence * 100).toStringAsFixed(0);
    final isDetecting = _currentDetectedStyle == 'Detecting...' || !_isModelReady;
    final sampleCount = _sensorSamples.length;
    final minSamples = SwimmingStyleDetector.windowSize;
    final duration = (sampleCount * 0.05).toStringAsFixed(1);
    
    String statusText = '';
    if (!_isModelReady) {
      statusText = 'Loading model...';
    } else if (sampleCount < minSamples) {
      statusText = 'Collecting: $sampleCount/$minSamples';
    } else if (_currentDetectedStyle == 'Detecting...') {
      statusText = 'Analyzing ${duration}s of data...';
    } else {
      statusText = 'Confidence: $confidencePercent% | Segments: ${_segments.length + 1}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDetecting)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              else
                Icon(styleIcon, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentDetectedStyle.toUpperCase(),
                    style: const TextStyle(
                      color: lightTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: lightTextColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getStyleIcon(String style) {
    switch (style.toLowerCase()) {
      case 'freestyle':
        return Icons.pool;
      case 'backstroke':
        return Icons.airline_seat_flat;
      case 'breaststroke':
        return Icons.air;
      case 'butterfly':
        return Icons.waves;
      case 'notswimming':
      case 'not swimming':
        return Icons.pause_circle_outline;
      case 'unknown':
        return Icons.help_outline;
      case 'rest':
        return Icons.pause_circle_outline;
      case 'transition':
        return Icons.shuffle;
      case 'detecting...':
        return Icons.search;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStopwatch(BuildContext context) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    String timeString;
    if (hours > 0) {
      timeString =
      '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    } else {
      timeString =
      '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }

    final fontSize = responsive(
      context: context,
      sm: 72.0,
      md: 88.0,
      lg: 100.0,
      xl: 120.0,
    );

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          timeString,
          style: TextStyle(
            color: lightTextColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w100,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricColumn(
            value: "${distance.toStringAsFixed(0)} m",
            label: "Distance",
            color: primaryColor,
            icon: Icons.route_outlined,
          ),
          Container(width: 1, height: 60, color: Colors.white12),
          _buildMetricColumn(
            value: "$strokes",
            label: "Strokes",
            color: primaryColor,
            icon: Icons.rowing_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                color: lightTextColor,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (!isRecording) {
      return _buildStartButton();
    } else if (isPaused) {
      return _buildPausedButtons();
    } else {
      return _buildPauseButton();
    }
  }

  Widget _buildStartButton() {
    final size = responsive(
      context: context,
      sm: 120.0,
      md: 140.0,
      lg: 160.0,
      xl: 180.0,
    );

    return SizedBox(
      width: size,
      height: size,
      child: _roundButton(
        color: primaryColor,
        icon: Icons.play_arrow_rounded,
        onPressed: _startRecording,
        iconSize: responsive(context: context, sm: 44.0, md: 48.0, lg: 52.0),
      ),
    );
  }

  Widget _buildPausedButtons() {
    final smallSize = responsive(context: context, sm: 88.0, md: 100.0, lg: 120.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive(context: context, sm: 12, md: 24, lg: 40)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: smallSize,
            height: smallSize,
            child: _roundButton(
              color: primaryColor,
              icon: Icons.play_arrow_rounded,
              onPressed: _resumeRecording,
              iconSize: responsive(context: context, sm: 32.0, md: 36.0, lg: 40.0),
            ),
          ),
          SizedBox(
            width: smallSize,
            height: smallSize,
            child: _roundButton(
              color: warningColor,
              icon: Icons.stop_rounded,
              onPressed: _stopRecording,
              iconSize: responsive(context: context, sm: 32.0, md: 36.0, lg: 40.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseButton() {
    final size = responsive(context: context, sm: 120.0, md: 140.0, lg: 160.0);

    return SizedBox(
      width: size,
      height: size,
      child: _roundButton(
        color: accentColor,
        icon: Icons.pause_rounded,
        onPressed: _pauseRecording,
        iconSize: responsive(context: context, sm: 44.0, md: 48.0, lg: 52.0),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return FloatingBottomBar(
      currentIndex: 1,
      onTap: (index) {
        if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
        if (index == 2) Navigator.pushReplacementNamed(context, '/history');
      },
      isSmall: true,
    );
  }

  Widget _roundButton({
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    double iconSize = 50,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(10),
        elevation: 6,
      ),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: iconSize,
        color: lightTextColor,
      ),
    );
  }
}