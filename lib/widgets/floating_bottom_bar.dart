import 'package:flutter/material.dart';

class FloatingBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isSmall; // 👈 tambahan

  const FloatingBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isSmall = false, // default: normal
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isSmall ? 30 : 30,
        left: isSmall ? 32 : 24,
        right: isSmall ? 32 : 24,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmall ? 20 : 30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF104193),
            Color(0xFF05142D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 20 : 20,
          vertical: isSmall ? 8 : 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomIcon(
              icon: Icons.home,
              label: isSmall ? '' : 'Home',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
              isSmall: isSmall,
            ),
            _BottomIcon(
              icon: Icons.album,
              label: isSmall ? '' : 'Record',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
              isSmall: isSmall,
            ),
            _BottomIcon(
              icon: Icons.history,
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
    final color = selected ? Colors.white : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: isSmall ? 22 : 26,
          ),
          if (!isSmall)
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

