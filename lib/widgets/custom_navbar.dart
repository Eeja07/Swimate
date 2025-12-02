import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const CustomNavbar({
    super.key,
    required this.title,
    this.showBackButton = false,
  });

  // Konstanta untuk tinggi App Bar
  static const double _kToolbarHeight = 70.0;
  // Konstanta untuk radius melengkung di bagian bawah
  static const double _kBottomRadius = 25.0;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Matikan tombol kembali otomatis bawaan AppBar
      automaticallyImplyLeading: false,
      // Hilangkan elevation bawaan AppBar karena kita akan menggunakan shadow kustom
      elevation: 0,
      toolbarHeight: _kToolbarHeight,
      backgroundColor: Colors.transparent,

      // 🟦 Gradient background dan Rounded Bottom
      flexibleSpace: Container(
        decoration: BoxDecoration(
          // Tambahkan border radius hanya di kiri dan kanan bawah
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(_kBottomRadius),
            bottomRight: Radius.circular(_kBottomRadius),
          ),
          // Tambahkan shadow untuk efek mengambang
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1976D2), // primaryColor: Biru default
              Color(0xFF0D47A1), // Warna yang lebih gelap
            ],
          ),
        ),
      ),

      // --- Tampilan Header ---

      // 1. Atur Tampilan Tombol Kembali (Leading)
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      )
          : null,

      // 2. Atur Judul dan Posisinya
      centerTitle: showBackButton, // Pusatkan jika ada back button

      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22, // Ukuran sedikit diperbesar
          fontWeight: FontWeight.w600, // Ketebalan sedikit dikurangi agar elegan
        ),
      ),

      // 3. Atur Ikon Aksi (Actions)
      actions: [
        if (!showBackButton)
          Row(
            children: [
              IconButton(
                onPressed: () {},
                // Ikon notifikasi menggunakan accent color (optional)
                icon: const Icon(Icons.notifications_none_outlined, size: 30, color: Colors.white),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0), // Padding disesuaikan
                  child: ClipOval(
                    child: Container(
                      width: 38, // Ukuran sedikit diperbesar
                      height: 38,
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.5), // Accent color sebagai background
                      child: const Icon(
                        Icons.person,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_kToolbarHeight);
}