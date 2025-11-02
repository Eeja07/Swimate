import 'package:flutter/material.dart';
import 'package:swimate/widgets/style_card.dart';
import '../widgets/custom_navbar.dart'; // Menggunakan AppBar yang sama
import 'package:url_launcher/url_launcher.dart'; // Impor untuk membuka link

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  // Fungsi untuk membuka URL
  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomNavbar(
        title: "Swimming Style",
        showBackButton: true,
      ),
      // Gunakan ListView untuk daftar yang bisa di-scroll
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Kartu 1: Freestyle
          TrendCard(
            title: "Freestyle",
            imagePath: 'assets/images/free.jpg', // Ganti dengan path gambar Anda
            onTap: () {
              _openUrl("https://en.wikipedia.org/wiki/Front_crawl");
            },
          ),
          const SizedBox(height: 16),

          // Kartu 2: Breaststroke
          TrendCard(
            title: "Breaststroke",
            imagePath: 'assets/images/breast.jpg', // Ganti dengan path gambar Anda
            onTap: () {
              _openUrl("https://en.wikipedia.org/wiki/Breaststroke");
            },
          ),
          const SizedBox(height: 16),

          // Kartu 3: Butterfly
          TrendCard(
            title: "Butterfly",
            imagePath: 'assets/images/butterfly.jpg', // Ganti dengan path gambar Anda
            onTap: () {
              _openUrl("https://en.wikipedia.org/wiki/Butterfly_stroke");
            },
          ),
          const SizedBox(height: 16),

          // Kartu 4: Backstroke
          TrendCard(
            title: "Backstroke",
            imagePath: 'assets/images/back.jpg', // Ganti dengan path gambar Anda
            onTap: () {
              _openUrl("https://en.wikipedia.org/wiki/Backstroke");
            },
          ),
        ],
      ),
    );
  }
}
