import 'package:flutter/material.dart';
import '../widgets/floating_bottom_bar.dart';
import '../widgets/custom_navbar.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'confirm_activity.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

// FIX: Added TickerProviderStateMixin to provide vsync for the AnimationController.
class _RecordPageState extends State<RecordPage> with TickerProviderStateMixin {
  bool isRecording = false;
  bool isPaused = false;
  int seconds = 0;
  Timer? _timer;

  // Sensor recording
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;
  Timer? _sensorTimer;
  final List<Map<String, dynamic>> _sensorSamples = [];

  // stroke count (detected from accelerometer peaks)
  int strokes = 0;
  // distance in meters (updated from GPS)
  double distance = 0.0;

  // GPS
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;

  // stroke detection helpers
  double _lastAccelMag = 0.0;
  int _lastStrokeTime = 0; // epoch ms

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // GPS UI status
  String _gpsStatus = 'Unknown'; // Unknown, Searching, Locked, Disabled, Denied

  Future<void> _updateGpsStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

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

      if (mounted) setState(() => _gpsStatus = newStatus);
    } catch (e) {
      debugPrint('Error checking GPS status: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _updateGpsStatus();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this, // This now works because of the TickerProviderStateMixin
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
        );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel(); // FIX: Added timer disposal to prevent memory leaks.
    _sensorTimer?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  // ⏱️ Mulai stopwatch
  void _startRecording() {
    setState(() {
      isRecording = true;
      isPaused = false;
    });
    // start main timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          seconds++;
          // distance updated by GPS stream; fallback simulation if no GPS
          if (_lastPosition == null) distance += 0.5;
        });
      }
    });

    // clear previous sensor samples
    _sensorSamples.clear();

    // subscribe to sensor streams and keep last values
    _accelSub = accelerometerEvents.listen((event) {
      _lastAccel = event;
    });

    _gyroSub = gyroscopeEvents.listen((event) {
      _lastGyro = event;
    });

    // start GPS stream (request permission if needed) and seed initial position
    Future.microtask(() async {
      // update status before requesting/starting stream
      _updateGpsStatus();
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          // permission denied — keep using simulated distance
          return;
        }

        // seed last position immediately so we can compute real delta from the first GPS reading
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
          );
          _lastPosition = pos;
        } catch (e) {
          // ignore getCurrentPosition failures, stream will provide updates
        }

        _positionSub =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                distanceFilter: 1,
              ),
            ).listen((pos) {
              if (_lastPosition != null) {
                final d = Geolocator.distanceBetween(
                  _lastPosition!.latitude,
                  _lastPosition!.longitude,
                  pos.latitude,
                  pos.longitude,
                );
                if (d.isFinite && d > 0) {
                  if (mounted) setState(() => distance += d);
                }
              }
              _lastPosition = pos;
            });
      } catch (e) {
        // any geolocator error -> fallback to simulated distance
        debugPrint('Geolocator error: $e');
      }
    });

    // sample combined sensor values at a fixed interval (e.g., 50ms)
    _sensorTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ax = _lastAccel?.x ?? 0.0;
      final ay = _lastAccel?.y ?? 0.0;
      final az = _lastAccel?.z ?? 0.0;
      final gx = _lastGyro?.x ?? 0.0;
      final gy = _lastGyro?.y ?? 0.0;
      final gz = _lastGyro?.z ?? 0.0;

      final mag = math.sqrt(ax * ax + ay * ay + az * az);

      // simple stroke detection: detect peak crossing above threshold and debounce
      const double threshold = 15.4; // tune this value
      if (mag > threshold &&
          _lastAccelMag <= threshold &&
          (now - _lastStrokeTime) > 400) {
        strokes++;
        _lastStrokeTime = now;
      }

      _lastAccelMag = mag;

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

  // ⏸️ Pause stopwatch
  void _pauseRecording() {
    setState(() => isPaused = true);
    _timer?.cancel();
    // pause sensor subscriptions/sampling
    _sensorTimer?.cancel();
    _accelSub?.pause();
    _gyroSub?.pause();
    _positionSub?.pause();
  }

  // ▶️ Resume stopwatch
  void _resumeRecording() {
    setState(() => isPaused = false);
    // resume timers and sensor sampling
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          seconds++;
          // distance updated by GPS; keep fallback
          if (_lastPosition == null) distance += 0.5;
        });
      }
    });

    _accelSub?.resume();
    _gyroSub?.resume();
    _positionSub?.resume();

    _sensorTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ax = _lastAccel?.x ?? 0.0;
      final ay = _lastAccel?.y ?? 0.0;
      final az = _lastAccel?.z ?? 0.0;
      final gx = _lastGyro?.x ?? 0.0;
      final gy = _lastGyro?.y ?? 0.0;
      final gz = _lastGyro?.z ?? 0.0;

      final mag = math.sqrt(ax * ax + ay * ay + az * az);

      const double threshold = 12.0;
      if (mag > threshold &&
          _lastAccelMag <= threshold &&
          (now - _lastStrokeTime) > 400) {
        strokes++;
        _lastStrokeTime = now;
      }

      _lastAccelMag = mag;

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

  // ⏹️ Stop recording
  void _stopRecording() {
    // stop timers and sensor subscriptions
    _timer?.cancel();
    _sensorTimer?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _positionSub?.cancel();

    final recordedSeconds = seconds;
    final recordedDistance = distance;
    final recordedStrokes = strokes;
    final recordedSensors = List<Map<String, dynamic>>.from(_sensorSamples);

    setState(() {
      isRecording = false;
      isPaused = false;
      seconds = 0;
      strokes = 0;
      distance = 0.0;
      _sensorSamples.clear();
      _lastPosition = null;
    });

    // Navigate to confirm activity page with recorded data and sensors
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmActivityPage(
            durationSeconds: recordedSeconds,
            distance: recordedDistance,
            strokes: recordedStrokes,
            sensorData: recordedSensors,
          ),
        ),
      );
    }
  }

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stopwatch with 4 baris (jam, menit, detik, distance+pace)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 35),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 🕐 JAM
                      _timeRow(
                        value: (seconds ~/ 3600).toString().padLeft(1, '0'),
                        unit: 'h',
                        valueColor: const Color(0xFF3A3B3C),
                        unitColor: const Color(0xFFFF5500),
                      ),

                      // ⏱️ MENIT
                      _timeRow(
                        value: ((seconds % 3600) ~/ 60).toString().padLeft(
                          1,
                          '0',
                        ),
                        unit: 'm',
                        valueColor: const Color(0xFF006AFF),
                        unitColor: const Color(0xFFFF5500),
                      ),

                      // ⏰ DETIK
                      _timeRow(
                        value: (seconds % 60).toString().padLeft(1, '0'),
                        unit: 's',
                        valueColor: const Color(0xFFFFFFFF),
                        unitColor: const Color(0xFFFF5500),
                      ),

                      const SizedBox(height: 20),

                      // 🌊 Distance & Pace
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${distance.toStringAsFixed(1)} m",
                                style: const TextStyle(
                                  color: Color(0xFF006AFF),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Distance",
                                style: TextStyle(
                                  color: Color(0xFF3A3B3C),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                "${strokes}",
                                style: const TextStyle(
                                  color: Color(0xFFF1DF4D),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Strokes",
                                style: TextStyle(
                                  color: Color(0xFF3A3B3C),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🟢 Tombol aksi utama
                _buildMainButton(),

                // Spacer so the main button doesn't overlap the bottom bar
                SizedBox(height: MediaQuery.of(context).padding.bottom + 60),
              ],
            ),
          ),
        ),
      ),

      // 🧭 Bottom bar kecil otomatis
      bottomNavigationBar: FloatingBottomBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
          if (index == 2) Navigator.pushReplacementNamed(context, '/history');
        },
        isSmall: true, // << bar jadi kecil di RecordPage
      ),
    );
  }

  Widget _buildMainButton() {
    if (!isRecording) {
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
    } else if (isPaused) {
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
    } else {
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
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 40, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
    );
  }
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
