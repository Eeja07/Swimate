import 'package:flutter/material.dart';

// --- Konstanta Warna Tema ---
const Color primaryColor = Color(0xFF1976D2); // Biru yang konsisten
const Color accentColor = Color(0xFF4FC3F7); // Biru muda untuk highlight
const Color darkBgColor = Color(0xFF0D47A1); // Warna gelap untuk gradient end
const Color lightTextColor = Colors.white;

class FloatingBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isSmall;

  const FloatingBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    // Menentukan margin dan radius berdasarkan isSmall
    final double horizontalMargin = isSmall ? 32 : 24;
    final double verticalMargin = 30;
    final double borderRadius = isSmall ? 25 : 35;

    return Container(
      margin: EdgeInsets.only(
        bottom: verticalMargin,
        left: horizontalMargin,
        right: horizontalMargin,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // Menggunakan primary dan darkBgColor untuk gradient
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor, // Mulai dari warna tema utama
            darkBgColor,  // Berakhir di warna yang lebih gelap
          ],
        ),
        boxShadow: [
          // Shadow yang lebih menonjol dan serasi dengan tema gelap
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        // Padding disesuaikan
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 10 : 16,
          vertical: isSmall ? 10 : 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomIcon(
              icon: Icons.home_rounded, // Menggunakan ikon rounded untuk estetika
              label: isSmall ? '' : 'Home',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
              isSmall: isSmall,
            ),
            _BottomIcon(
              icon: Icons.track_changes_rounded,
              label: isSmall ? '' : 'Record',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
              isSmall: isSmall,
            ),
            _BottomIcon(
              icon: Icons.history_toggle_off_rounded,
              label: isSmall ? '' : 'History',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
              isSmall: isSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isSmall;
  final VoidCallback onTap;

  const _BottomIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final double iconSize = isSmall ? 22 : 28;

    // Menggunakan AnimatedContainer untuk indikator yang dipilih
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 12,
          vertical: isSmall ? 1 : 3,
        ),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.2) : Colors.transparent, // Highlight transparan
          borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? accentColor : lightTextColor.withValues(alpha: 0.7), // Ikon accent jika dipilih
              size: iconSize,
            ),
            if (!isSmall && label.isNotEmpty) // Pastikan label tidak kosong saat tidak small
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? lightTextColor : lightTextColor.withValues(alpha: 0.7), // Teks putih jika dipilih
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}