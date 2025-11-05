import 'package:flutter/material.dart';
import '../widgets/floating_bottom_bar.dart';
import '../widgets/custom_navbar.dart';
import 'dart:async';

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

  double pace = 0.0;
  double distance = 0.0;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this, // This now works because of the TickerProviderStateMixin
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
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
    super.dispose();
  }

  // ⏱️ Mulai stopwatch
  void _startRecording() {
    setState(() {
      isRecording = true;
      isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) { // Good practice to check if widget is still in tree
        setState(() {
          seconds++;
          distance += 0.5; // simulasi jarak
          pace = seconds > 0 ? distance / (seconds / 60) : 0; // pace per menit
        });
      }
    });
  }

  // ⏸️ Pause stopwatch
  void _pauseRecording() {
    setState(() => isPaused = true);
    _timer?.cancel();
  }

  // ▶️ Resume stopwatch
  void _resumeRecording() {
    setState(() => isPaused = false);
    _startRecording(); // Re-using _startRecording logic is cleaner
  }

  // ⏹️ Stop recording
  void _stopRecording() {
    _timer?.cancel();
    setState(() {
      isRecording = false;
      isPaused = false;
      seconds = 0;
      pace = 0.0;
      distance = 0.0;
    });
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
                        value: ((seconds % 3600) ~/ 60).toString().padLeft(1, '0'),
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
                                "${pace.toStringAsFixed(1)} m/min",
                                style: const TextStyle(
                                  color: Color(0xFFF1DF4D),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Pace",
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
