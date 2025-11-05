import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import semua halaman
import 'pages/cover.dart';
import 'pages/signup.dart';
import 'pages/signin.dart';
import 'pages/age.dart';
import 'pages/height.dart';
import 'pages/weight.dart';
import 'pages/collection_page.dart';
import 'pages/dashboard_screen.dart';
import 'pages/history_page.dart';
import 'pages/record_page.dart';
import 'pages/style_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kulswluykfozsyxitgjo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt1bHN3bHV5a2ZvenN5eGl0Z2pvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4ODM5NzcsImV4cCI6MjA3NzQ1OTk3N30.uJWRUD8t5ypbCkgOPMU6xNTH3iNsiZdekg_av_A4vpM',
  );

  runApp(const SwimateApp());
}

class SwimateApp extends StatefulWidget {
  const SwimateApp({super.key});

  @override
  State<SwimateApp> createState() => _SwimateAppState();
}

class _SwimateAppState extends State<SwimateApp> {
  @override
  void initState() {
    super.initState();

    // 🔥 Listener Supabase Auth untuk login/logout/deep link
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (!mounted) return;

      switch (event) {
        case AuthChangeEvent.signedIn:
          // 🔹 Kalau datang dari verifikasi email (deep link), arahkan ke /signin
          if (session?.user.emailConfirmedAt != null &&
              ModalRoute.of(context)?.settings.name == '/age') {
            debugPrint('✅ Email verified via deep link, go to age');
            Navigator.pushNamedAndRemoveUntil(context, '/age', (_) => false);
          } else {
            debugPrint('✅ Normal login detected, go to dashboard');
            Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
          }
          break;

        case AuthChangeEvent.signedOut:
          debugPrint('🚪 User logged out or session expired');
          Navigator.pushNamedAndRemoveUntil(context, '/cover', (_) => false);
          break;

        default:
          break;
      }
    }); 
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swimate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),

      // Halaman pertama
      initialRoute: '/cover',

      onGenerateRoute: (settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case '/cover':
            builder = (context) => const CoverPage();
            break;
          case '/signup':
            builder = (context) => const SignupPage();
            break;
          case '/signin':
            builder = (context) => const SigninPage();
            break;
          case '/age':
            builder = (context) => const AgePickerScreen();
            break;
          case '/height':
            builder = (context) => const HeightPickerScreen();
            break;
          case '/weight':
            builder = (context) => const WeightPickerScreen();
            break;
          case '/dashboard':
            builder = (context) => const DashboardScreen();
            break;
          case '/record':
            builder = (context) => const RecordPage();
            break;
          case '/history':
            builder = (context) => const HistoryPage();
            break;
          case '/style':
            builder = (context) => const TrendsPage();
            break;
          case '/collection':
            builder = (context) => const CollectionPage();
            break;
          default:
            builder = (context) => const CoverPage();
        }

        // Animasi transisi fade
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        );
      },
    );
  }
}