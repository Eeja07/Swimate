import 'package:flutter/material.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  const CustomNavbar({super.key, required this.title, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Matikan tombol kembali otomatis bawaan AppBar
      automaticallyImplyLeading: false,
      elevation: 4,
      toolbarHeight: 70,
      backgroundColor: Colors.transparent, // transparan agar gradient terlihat

      // 🟦 Gradient background
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF104193), // biru tua
              Color(0xFF05142D), // biru kehitaman
            ],
          ),
        ),
      ),

      // --- PERUBAHAN UTAMA DI SINI ---

      // 1. Atur Tampilan Tombol Kembali (Leading)
      // Jika `showBackButton` true, tampilkan tombol kembali. Jika tidak, jangan tampilkan apa-apa.
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      )
          : null, // `null` akan membuat leading hilang dan title bergeser ke kiri.

      // 2. Atur Judul dan Posisinya
      // Jika ada tombol kembali, pusatkan judul. Jika tidak, judul akan otomatis rata kiri.
      centerTitle: showBackButton,

      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // 3. Atur Ikon Aksi (Actions)
      // Ikon-ikon ini hanya akan muncul jika TIDAK ada tombol kembali.
      actions: [
        if (!showBackButton)
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications, size: 30, color: Colors.white),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: const ClipOval(
                  child: Icon(Icons.account_circle, size: 30, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16), // Beri jarak di ujung kanan
            ],
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
