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
import 'pages/profile.dart';
import 'pages/confirm_activity.dart';
import 'pages/reset_password.dart';
import 'pages/history_detail.dart';

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
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      debugPrint('🔔 Auth event: $event');

      // ✅ Tunggu frame selesai
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // ✅ Gunakan navigator key untuk navigasi
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session?.user != null) {
            debugPrint('👤 User signed in: ${session!.user.email}');

            // 🔍 Cek apakah user baru
            final isNewUser = await _isNewUser(session.user.id);

            if (!mounted) return;

            if (isNewUser) {
              debugPrint('✅ New user → /age');
              navigator.pushNamedAndRemoveUntil('/age', (_) => false);
            } else {
              debugPrint('✅ Existing user → /dashboard');
              navigator.pushNamedAndRemoveUntil('/dashboard', (_) => false);
            }
          }
          break;

        case AuthChangeEvent.signedOut:
          debugPrint('🚪 Signed out → /cover');
          navigator.pushNamedAndRemoveUntil('/cover', (_) => false);
          break;

        case AuthChangeEvent.tokenRefreshed:
          debugPrint('🔄 Token refreshed');
          break;

        default:
          break;
      }
    });
  }

  Future<bool> _isNewUser(String userId) async {
    try {
      debugPrint('🔍 Checking if user is new: $userId');

      final response = await Supabase.instance.client
          .from('profiles')
          .select('age, height, weight')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('📝 No profile found → New user');
        return true;
      }

      final age = response['age'] ?? 0;
      final height = response['height'] ?? 0;
      final weight = response['weight'] ?? 0;

      debugPrint('📊 Profile: age=$age, height=$height, weight=$weight');

      final isNew = (age == 0 && height == 0 && weight == 0);
      debugPrint(isNew ? 'User is new' : '👴 User is existing');

      return isNew;
    } catch (e) {
      debugPrint('❌ Error checking profile: $e');
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey, // 🔑 Key untuk navigasi dari listener
      title: 'Swimate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),

      initialRoute: '/cover',

      onGenerateRoute: (settings) {
        debugPrint(' Navigating to: ${settings.name}');

        WidgetBuilder builder;
        switch (settings.name) {
          case '/profile':
            builder = (context) => const ProfilePage();
            break;
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
          case '/confirm_activity':
            builder = (context) => const ConfirmActivityPage(
              durationSeconds: 0,
              distance: 0.0,
              strokes: 0,
            );
            break;
          case '/reset-password':
            builder = (context) => const ResetPasswordPage();
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
          case '/history-detail':
            builder = (context) => const HistoryDetailPage();
            break;
          default:
            builder = (context) => const CoverPage();
        }

        return PageRouteBuilder(
          settings: settings,
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
