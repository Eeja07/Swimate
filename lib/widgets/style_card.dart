import 'package:flutter/material.dart';

class TrendCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final VoidCallback onTap;

  const TrendCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Background Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image.asset(
              imagePath,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              // Tambahkan error builder untuk menangani jika gambar tidak ditemukan
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey.shade800,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.white54, size: 40),
                  ),
                );
              },
            ),
          ),
          // Gradient overlay
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.0)
                ],
              ),
            ),
          ),
          // Text Content
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
