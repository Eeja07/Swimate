import 'package:flutter/material.dart';
import '../widgets/floating_bottom_bar.dart';
import '../widgets/custom_navbar.dart';
import 'dart:async';
import 'confirm_activity.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with TickerProviderStateMixin {
  // ==================== STATE VARIABLES ====================
  
  // Recording state
  bool isRecording = false;
  bool isPaused = false;
  int seconds = 0;
  
  // Activity metrics
  int strokes = 0;
  double distance = 0.0;
  
  // Timers
  Timer? _mainTimer;
  Timer? _sensorTimer;
  
  // Sensor data
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  AccelerometerEvent? _lastAccelEvent;
  GyroscopeEvent? _lastGyroEvent;
  final List<Map<String, dynamic>> _sensorSamples = [];
  
  // Stroke detection
  double _lastAccelMagnitude = 0.0;
  int _lastStrokeTimestamp = 0;
  
  // GPS tracking
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  
  // Animations
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Swimming style segments
  final List<Map<String, dynamic>> _segments = [];
  String _currentStyle = 'freestyle';
  int _segmentStartTime = 0;
  Timer? _styleChangeTimer;

  // List of swimming styles
  final List<String> _swimmingStyles = [
    'freestyle',
    'backstroke',
    'breaststroke',
    'butterfly',
  ];

  // ==================== LIFECYCLE METHODS ====================
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  
  void _initializeAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
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

  void _disposeResources() {
    _animController.dispose();
    _mainTimer?.cancel();
    _sensorTimer?.cancel();
    _styleChangeTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();
  }

  // ==================== GPS STATUS ====================
  
  Future<void> _updateGpsStatus() async {
    // This method checks GPS status for potential UI indicators
    // Currently not used but kept for future GPS status display
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

      // Status can be used for UI feedback in the future
      debugPrint('GPS Status: $newStatus');
    } catch (e) {
      debugPrint('Error checking GPS status: $e');
    }
  }

  // ==================== SWIMMING STYLE SEGMENT TRACKING ====================

  void _startStyleTracking() {
    _segments.clear();
    _currentStyle = _getRandomStyle();
    _segmentStartTime = seconds;
    
    // Change style randomly every 15-45 seconds
    _scheduleNextStyleChange();
  }

  void _scheduleNextStyleChange() {
    _styleChangeTimer?.cancel();
    
    // Random duration between 15-45 seconds
    final randomSeconds = 15 + (math.Random().nextInt(31));
    
    _styleChangeTimer = Timer(Duration(seconds: randomSeconds), () {
      if (isRecording && !isPaused) {
        _changeSwimmingStyle();
        _scheduleNextStyleChange();
      }
    });
  }

  void _changeSwimmingStyle() {
    // Save current segment
    _segments.add({
      'style': _currentStyle,
      'start_time': _segmentStartTime,
      'end_time': seconds,
      'duration': seconds - _segmentStartTime,
    });
    
    // Change to new random style (different from current)
    String newStyle;
    do {
      newStyle = _getRandomStyle();
    } while (newStyle == _currentStyle && _swimmingStyles.length > 1);
    
    setState(() {
      _currentStyle = newStyle;
      _segmentStartTime = seconds;
    });
    
    debugPrint('Style changed to: $_currentStyle');
  }

  String _getRandomStyle() {
    return _swimmingStyles[math.Random().nextInt(_swimmingStyles.length)];
  }

  void _finalizeSegments() {
    // Add final segment
    if (_segmentStartTime < seconds) {
      _segments.add({
        'style': _currentStyle,
        'start_time': _segmentStartTime,
        'end_time': seconds,
        'duration': seconds - _segmentStartTime,
      });
    }
  }

  // ==================== RECORDING CONTROLS ====================
  
  void _startRecording() {
    setState(() {
      isRecording = true;
      isPaused = false;
    });
    
    _startMainTimer();
    _startSensorTracking();
    _startGpsTracking();
    _startStyleTracking();
  }

  void _pauseRecording() {
    setState(() => isPaused = true);
    
    _mainTimer?.cancel();
    _sensorTimer?.cancel();
    _styleChangeTimer?.cancel();
    _accelSubscription?.pause();
    _gyroSubscription?.pause();
    _positionSubscription?.pause();
  }

  void _resumeRecording() {
    setState(() => isPaused = false);
    
    _startMainTimer();
    _startSensorSampling();
    _scheduleNextStyleChange();
    _accelSubscription?.resume();
    _gyroSubscription?.resume();
    _positionSubscription?.resume();
  }

  void _stopRecording() {
    // Finalize segments
    _finalizeSegments();
    
    // Save data before resetting
    final recordedSeconds = seconds;
    final recordedDistance = distance;
    final recordedStrokes = strokes;
    final recordedSensors = List<Map<String, dynamic>>.from(_sensorSamples);
    final recordedSegments = List<Map<String, dynamic>>.from(_segments);

    // Stop all tracking
    _mainTimer?.cancel();
    _sensorTimer?.cancel();
    _styleChangeTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();

    // Reset state
    setState(() {
      isRecording = false;
      isPaused = false;
      seconds = 0;
      strokes = 0;
      distance = 0.0;
      _sensorSamples.clear();
      _segments.clear();
      _lastPosition = null;
    });

    // Navigate to confirmation page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmActivityPage(
            durationSeconds: recordedSeconds,
            distance: recordedDistance,
            strokes: recordedStrokes,
            sensorData: recordedSensors,
            segments: recordedSegments,
          ),
        ),
      );
    }
  }

  // ==================== TIMER MANAGEMENT ====================
  
  void _startMainTimer() {
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          seconds++;
          // Fallback distance simulation if GPS unavailable
          if (_lastPosition == null) {
            distance += 0.5;
          }
        });
      }
    });
  }

  // ==================== SENSOR TRACKING ====================
  
  void _startSensorTracking() {
    _sensorSamples.clear();

    // Subscribe to accelerometer
    _accelSubscription = accelerometerEventStream().listen((event) {
      _lastAccelEvent = event;
    });

    // Subscribe to gyroscope
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
      
      // Get current sensor values
      final ax = _lastAccelEvent?.x ?? 0.0;
      final ay = _lastAccelEvent?.y ?? 0.0;
      final az = _lastAccelEvent?.z ?? 0.0;
      final gx = _lastGyroEvent?.x ?? 0.0;
      final gy = _lastGyroEvent?.y ?? 0.0;
      final gz = _lastGyroEvent?.z ?? 0.0;

      // Calculate acceleration magnitude
      final magnitude = math.sqrt(ax * ax + ay * ay + az * az);

      // Detect stroke (peak crossing with debounce)
      if (_isStrokeDetected(magnitude, now, strokeThreshold, strokeDebounceMs)) {
        strokes++;
        _lastStrokeTimestamp = now;
      }

      _lastAccelMagnitude = magnitude;

      // Store sample
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

  // ==================== GPS TRACKING ====================
  
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

  // ==================== UI BUILD METHODS ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: const CustomNavbar(title: "Record"),
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _buildBody(context),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCurrentStyleIndicator(),
          const SizedBox(height: 12),
          _buildStopwatch(),
          const SizedBox(height: 20),
          _buildMetrics(),
          const SizedBox(height: 20),
          _buildActionButton(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 60),
        ],
      ),
    );
  }

  Widget _buildCurrentStyleIndicator() {
    if (!isRecording) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF006AFF).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF006AFF), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pool, color: Color(0xFF006AFF), size: 18),
          const SizedBox(width: 8),
          Text(
            _currentStyle.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF006AFF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopwatch() {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 35),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _timeRow(
            value: hours.toString(),
            unit: 'h',
            valueColor: const Color(0xFF3A3B3C),
            unitColor: const Color(0xFFFF5500),
          ),
          _timeRow(
            value: minutes.toString(),
            unit: 'm',
            valueColor: const Color(0xFF006AFF),
            unitColor: const Color(0xFFFF5500),
          ),
          _timeRow(
            value: secs.toString(),
            unit: 's',
            valueColor: const Color(0xFFFFFFFF),
            unitColor: const Color(0xFFFF5500),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMetricColumn(
          value: "${distance.toStringAsFixed(1)} m",
          label: "Distance",
          color: const Color(0xFF006AFF),
        ),
        _buildMetricColumn(
          value: "$strokes",
          label: "Strokes",
          color: const Color(0xFFF1DF4D),
        ),
      ],
    );
  }

  Widget _buildMetricColumn({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3A3B3C),
            fontSize: 14,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      child: SizedBox(
        width: double.infinity,
        child: _mainButton(
          label: "Start",
          color: const Color(0xFF006AFF),
          icon: Icons.play_arrow,
          onPressed: _startRecording,
        ),
      ),
    );
  }

  Widget _buildPausedButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: _smallButton(
              label: "Resume",
              color: const Color(0xFF006AFF),
              icon: Icons.play_arrow,
              onPressed: _resumeRecording,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _smallButton(
              label: "Stop",
              color: Colors.white,
              icon: Icons.stop,
              onPressed: _stopRecording,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      child: SizedBox(
        width: double.infinity,
        child: _mainButton(
          label: "Pause",
          color: Colors.white,
          icon: Icons.pause,
          onPressed: _pauseRecording,
        ),
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

  // ==================== BUTTON WIDGETS ====================
  
  Widget _mainButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 30, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(fontSize: 20, color: Colors.black),
      ),
    );
  }

  Widget _smallButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 40, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
    );
  }

  Widget _timeRow({
    required String value,
    required String unit,
    required Color valueColor,
    required Color unitColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 96,
              fontWeight: FontWeight.w100,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              unit,
              style: TextStyle(
                color: unitColor,
                fontSize: 21,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}