import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/floating_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/style_card.dart';
import '../widgets/wave_background.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';

// --- Konstanta Warna Tema ---
const Color primaryColor = Color(0xFF1976D2);
const Color accentColor = Color(0xFF4FC3F7);
const Color darkCardColor = Color(0xFF162B44);
const Color lightTextColor = Colors.white;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late AnimationController _animController;
  late Animation<Offset> _pageSlideAnimation;
  late Animation<double> _pageFadeAnimation;
  late Animation<Offset> _bottomBarSlideAnimation;

  final ActivityService _activityService = ActivityService();
  ActivityModel? _latestActivity;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _pageSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOut),
        );

    _pageFadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    _bottomBarSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
    _loadLatestActivity();
  }

  Future<void> _loadLatestActivity() async {
    setState(() => _isLoading = true);
    
    final activity = await _activityService.getLatestActivity();
    
    setState(() {
      _latestActivity = activity;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/record');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/history');
    }
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  // ---------------------------------------------------------
  // BUILD SECTIONS
  // ---------------------------------------------------------

  Widget _buildActivityCard(String title, String value, IconData icon, {bool isLoading = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: darkCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accentColor, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: lightTextColor),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSensorDataCard() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/collection');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [primaryColor, Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.monitor_heart_outlined, color: lightTextColor, size: 40),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Collect Sensor Data",
                    style: TextStyle(
                      color: lightTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Start recording data for model training.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: lightTextColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.asset(
                  'assets/image/bg-dash-1.jpg',
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.1)
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Hello, Swimmer 👋",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: lightTextColor),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Welcome back! Ready for your next swim?",
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSensorDataCard(),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Activity",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: lightTextColor),
              ),
              IconButton(
                onPressed: _loadLatestActivity,
                icon: const Icon(Icons.refresh, color: accentColor),
                tooltip: 'Refresh data',
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildActivityCard(
                "Distance",
                _latestActivity?.formattedDistance ?? "0.0 km",
                Icons.route,
                isLoading: _isLoading,
              ),
              const SizedBox(width: 16),
              _buildActivityCard(
                "Pace",
                _latestActivity?.formattedPace ?? "0:00 /100m",
                Icons.speed,
                isLoading: _isLoading,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _buildActivityCard(
                "Stroke",
                _latestActivity?.formattedStrokes ?? "0",
                Icons.pool,
                isLoading: _isLoading,
              ),
              const SizedBox(width: 16),
              _buildActivityCard(
                "Total Time",
                _latestActivity?.formattedTotalTime ?? "0 min",
                Icons.timer_outlined,
                isLoading: _isLoading,
              ),
            ],
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Swimming Style",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: lightTextColor),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/style');
                },
                child: const Text(
                  "See more",
                  style: TextStyle(
                      color: accentColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TrendCard(
            title: "Breast Stroke",
            imagePath: 'assets/image/breast.jpg',
            onTap: () {
              _openUrl("https://en.wikipedia.org/wiki/Breaststroke");
            },
          ),

          const SizedBox(height: 100), // ruang bawah
        ],
      ),
    );
  }

  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomNavbar(title: "Home"),
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return WaveBackground(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: FadeTransition(
                    opacity: _pageFadeAnimation,
                    child: SlideTransition(
                      position: _pageSlideAnimation,
                      child: _buildBody(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SlideTransition(
        position: _bottomBarSlideAnimation,
        child: FadeTransition(
          opacity: _pageFadeAnimation,
          child: FloatingBottomBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
          ),
        ),
      ),
    );
  }
}