import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/record_page.dart';
import 'screens/style_page.dart';
import 'screens/history_page.dart';
import 'screens/collection_page.dart';

void main() {
  runApp(const SwimScienceApp());
}

class SwimScienceApp extends StatelessWidget {
  const SwimScienceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // hilangin banner debug
      title: 'SwimScience',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Inter', // opsional: bisa ganti font sesuai style kamu
      ),

      // Halaman pertama yang dibuka
      initialRoute: '/dashboard',

      // Daftar route app kamu
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
        '/record' : (_) => const RecordPage(),
        '/history': (context) => const HistoryPage(),
        '/style': (context) => const TrendsPage(),
        '/collection': (context) => const CollectionPage(),
      },
    );
  }
}
