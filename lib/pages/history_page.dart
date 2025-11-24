import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk memformat tanggal
import '../models/swim_session.dart'; // Impor model data kita
import '../widgets/custom_navbar.dart';
import '../widgets/floating_bottom_bar.dart';// Impor AppBar

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Data contoh untuk riwayat latihan. Nantinya ini bisa diambil dari database.
  final List<SwimSession> _sessions = [
    SwimSession(
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      title: "Morning Freestyle Drill",
      distance: "1.5 km",
      time: "30:15",
      pace: "2:01/100m",
      style: "Freestyle",
    ),
    SwimSession(
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      title: "Endurance Practice",
      distance: "2.0 km",
      time: "45:30",
      pace: "2:15/100m",
      style: "Mixed",
    ),
    SwimSession(
      timestamp: DateTime.now().subtract(const Duration(days: 10)),
      title: "Butterfly Technique",
      distance: "0.8 km",
      time: "25:00",
      pace: "3:05/100m",
      style: "Butterfly",
    ),
    SwimSession(
      timestamp: DateTime.now().subtract(const Duration(days: 15)),
      title: "Relaxed Swim",
      distance: "1.0 km",
      time: "22:10",
      pace: "2:13/100m",
      style: "Breaststroke",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomNavbar(
        title: "History",
        // Navbar untuk history tidak perlu tombol kembali
        showBackButton: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(_sessions[index]);
        },
      ),
      bottomNavigationBar: FloatingBottomBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
          if (index == 1) Navigator.pushReplacementNamed(context, '/record');
        },
        isSmall: false, // << bar jadi kecil di RecordPage

      ),
    );
  }

  // Widget untuk membuat satu kartu riwayat
  Widget _buildHistoryCard(SwimSession session) {
    return Card(
      color: const Color(0xFF1C1C1E), // Warna latar belakang kartu
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Timestamp dan Gaya Renang
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // Format tanggal agar mudah dibaca, misal: "Oct 26, 2025"
                  DateFormat('MMM d, yyyy').format(session.timestamp),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.style,
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Baris 2: Judul/Keterangan Aktivitas
            Text(
              session.title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Divider
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),

            // Baris 3: Detail (Distance, Time, Pace)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailColumn("Distance", session.distance),
                _buildDetailColumn("Time", session.time),
                _buildDetailColumn("Pace", session.pace),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget kecil untuk membuat kolom detail (misal: "Distance" dan nilainya)
  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
