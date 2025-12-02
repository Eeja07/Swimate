import 'package:flutter/material.dart';

class WaveBackground extends StatelessWidget {
  final Widget child;

  const WaveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Menggunakan ClipRect untuk memastikan gambar tidak meluber
    // keluar dari batas WaveBackground jika children-nya tidak pas.
    return ClipRect(
      child: CustomPaint(
        painter: _WavePainter(),
        child: child,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Daftar Warna untuk Gradasi.
    // Warna bisa diatur dari terang ke gelap, atau sebaliknya.
    // Di sini saya akan menggunakan nuansa biru yang mirip dengan kode awal.
    final List<Color> baseColors = [
      const Color(0xFF42A5F5), // Biru Muda
      const Color(0xFF1976D2), // Biru Sedang
      const Color(0xFF0D47A1), // Biru Tua
    ];

    // Daftar Opacity/Alpha untuk setiap layer gelombang (dari layer teratas ke terbawah)
    final List<double> waveOpacities = [0.10, 0.08, 0.05, 0.03, 0.02];

    // ====== WAVE NORMAL (melengkung ke atas) ======
    // Titik y awal untuk gelombang atas (diukur dari atas)
    final List<double> topHeights = [0.20, 0.35];

    // Iterasi untuk gelombang normal (melengkung ke atas)
    for (int i = 0; i < topHeights.length; i++) {
      final double startY = size.height * topHeights[i];

      // 1. Buat LinearGradient
      final gradient = LinearGradient(
        // Atur gradasi horizontal (dari kiri ke kanan)
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: baseColors.map((color) => color.withValues(alpha: waveOpacities[i])).toList(),
        // Atur stops jika diperlukan untuk kontrol lebih lanjut
      ).createShader(Rect.fromLTWH(0, startY, size.width, size.height * 0.2)); // Shader diikat ke area sekitar gelombang

      final paint = Paint()
        ..shader = gradient // Gunakan shader sebagai pengganti warna solid
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(0, startY)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * (topHeights[i] - 0.10), // Puncak gelombang
          size.width,
          startY,
        )
        ..lineTo(size.width, 0)
        ..lineTo(0, 0)
        ..close();

      canvas.drawPath(path, paint);
    }

    // ====== WAVE TERBALIK (melengkung ke bawah) ======
    // Titik y awal untuk gelombang bawah (diukur dari atas)
    final List<double> bottomHeights = [0.30, 0.45, 0.60, 0.75, 0.90];

    // Iterasi untuk gelombang terbalik (melengkung ke bawah)
    for (int i = 0; i < bottomHeights.length; i++) {
      final double startY = size.height * bottomHeights[i];

      // 1. Buat LinearGradient
      final gradient = LinearGradient(
        // Atur gradasi horizontal
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        // Opacity diambil dari waveOpacities, dijamin ada 5 elemen
        colors: baseColors.map((color) => color.withValues(alpha: waveOpacities[i])).toList(),
      ).createShader(Rect.fromLTWH(0, startY - size.height * 0.1, size.width, size.height * 0.2)); // Shader diikat ke area sekitar gelombang

      final paint = Paint()
        ..shader = gradient // Gunakan shader sebagai pengganti warna solid
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(0, startY)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * (bottomHeights[i] + 0.10), // Lembah gelombang
          size.width,
          startY,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}