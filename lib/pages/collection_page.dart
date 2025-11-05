import 'package:flutter/material.dart';
import 'package:swimate/widgets/custom_navbar.dart';
import 'dart:async';
import 'dart:io';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart'; // Untuk getApplicationDocumentsDirectory()
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart'; // Untuk membagikan file CSV

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  bool _isRecording = false;
  int _recordingTime = 0;
  Timer? _timer;
  String _selectedStyle = 'Freestyle'; // Default style

  StreamSubscription? _sensorSubscription;
  final List<String> _sensorDataRows = [];

  @override
  void dispose() {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  // --- FUNGSI UTAMA UNTUK MEREKAM DATA (VERSI DIPERBAIKI) ---
  Future<void> _startRecording() async {
    debugPrint("--- 1. Start Recording button pressed. ---");

    // Menghapus logika permintaan Permission.storage.
    // Kita akan menyimpan data di direktori privat aplikasi, yang tidak memerlukan izin runtime.
    debugPrint("--- 2. Memulai proses perekaman (menggunakan direktori privat aplikasi). ---");

    if (!mounted) return;

    setState(() {
      _isRecording = true;
      _recordingTime = 0;
      _sensorDataRows.clear();
    });

    // Header CSV
    _sensorDataRows.add('timestamp,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z,label');

    // Timer untuk Durasi
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingTime++;
        });
      }
    });

    // Menggabungkan stream Accelerometer dan Gyroscope, lalu membatasi laju (throttle)
    _sensorSubscription = CombineLatestStream.combine2(
      accelerometerEventStream(),
      gyroscopeEventStream(),
          (AccelerometerEvent accel, GyroscopeEvent gyro) {
        return {'accel': accel, 'gyro': gyro};
      },
    )
        .throttleTime(const Duration(milliseconds: 100))
        .listen((event) {
      final accel = event['accel'] as AccelerometerEvent;
      final gyro = event['gyro'] as GyroscopeEvent;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      _sensorDataRows.add(
          '$timestamp,${accel.x},${accel.y},${accel.z},${gyro.x},${gyro.y},${gyro.z},$_selectedStyle');
    }, onError: (error) {
      debugPrint("Sensor error: $error");
      if (_isRecording) {
        _stopRecording();
      }
    });
    debugPrint("--- 3. Sensor listeners telah dimulai. ---");
  }

  // --- Fungsi untuk Menyimpan dan Membagikan File ---
  Future<void> _stopRecording() async {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    _sensorSubscription = null;

    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }

    if (_sensorDataRows.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Tidak ada data yang direkam.")));
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    final csvContent = _sensorDataRows.join('\n');

    try {
      // 🎯 PERBAIKAN: Menggunakan getApplicationDocumentsDirectory()
      final directory = await getApplicationDocumentsDirectory();

      final path = directory.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'swim_data_${_selectedStyle}_$timestamp.csv';
      final file = File('$path/$fileName');

      await file.writeAsString(csvContent);

      if (mounted) {
        Navigator.of(context).pop();
        await _shareFile(file.path, fileName); // Memanggil fungsi sharing
      }

      debugPrint("SUCCESS: Data saved to ${file.path}. Initiating share dialog.");

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error menyimpan/membagikan file: $e")));
      }
      debugPrint("ERROR saving/sharing file: $e");
    } finally {
      _sensorDataRows.clear();
    }
  }

// --- FUNGSI DIPERBAIKI: Memicu Dialog Sharing Sistem ---
  Future<void> _shareFile(String filePath, String fileName) async {
    try {
      final file = XFile(filePath); // XFile sudah tersedia dari share_plus

      // Memicu dialog share sistem menggunakan SharePlus.instance.share dengan ShareParams
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: 'Data Sensor Renang Swimate (Style: $_selectedStyle)',
          subject: 'Data Sensor Swimate: $fileName',
        ),
      );
      
      if (mounted) {
        if (result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("File berhasil dibagikan!"),
            ),
          );
        } else if (result.status == ShareResultStatus.dismissed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sharing dibatalkan."),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error sharing file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal membuka dialog share: $e"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI tetap sama
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomNavbar(
        title: "Data Collection",
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indikator Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        _isRecording ? "RECORDING" : "STANDBY",
                        style: TextStyle(
                          color: _isRecording ? Colors.redAccent : Colors.greenAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text("STATUS", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_recordingTime}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text("TIME", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Dropdown
            const Text("Select Swimming Style (Label)", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStyle,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C1C1E),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (String? newValue) {
                    if (newValue != null && !_isRecording) {
                      setState(() {
                        _selectedStyle = newValue;
                      });
                    }
                  },
                  items: <String>[
                    'Freestyle',
                    'Breaststroke',
                    'Butterfly',
                    'Backstroke',
                    'Not_Swimming'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Spacer(),

            // Tombol Aksi
            if (_isRecording)
              ElevatedButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop_circle_outlined, size: 28),
                label: const Text("Stop Recording"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.play_circle_outline, size: 28),
                label: const Text("Start Recording"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}