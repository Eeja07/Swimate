import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/floating_bottom_bar.dart';
import 'dart:math' as math;
import '../widgets/wave_background.dart';

const Color primaryColor = Color(0xFF1976D2);
const Color accentColor = Color(0xFF4FC3F7);
const Color lightTextColor = Colors.white;
const Color darkCardColor = Color(0xFF1C1C1E);
const Color darkBgColor = Colors.black;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  final logger = Logger();

  String? get currentUserId => supabase.auth.currentUser?.id;

  List<Map<String, dynamic>> activities = [];

  bool isLoading = true;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Variabel untuk animasi latar belakang
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    loadActivitiesFromDatabase();

    // Inisialisasi controller animasi latar belakang
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Durasi lambat untuk efek ombak
    )..repeat(reverse: true); // Animasi berulang dan berbalik
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    super.dispose();
  }

  /// Fungsi untuk mengambil semua activities user dari database
  Future<void> loadActivitiesFromDatabase() async {
    if (currentUserId == null) {
      logger.w('User not authenticated, cannot load activities.');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final response = await supabase
          .from('activity_table')
          .select()
          .eq('id_user', currentUserId!)
          .order('timestamp', ascending: false);

      setState(() {
        activities = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      logger.i('✅ Loaded ${activities.length} activities');
    } catch (e) {
      logger.e('❌ Error loading activities', error: e);
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: const CustomNavbar(
        title: "History",
        showBackButton: false,
      ),
      extendBody: true,
        body: WaveBackground(
          child: Stack(
            children: [
          // Latar Belakang Pola Air Animasi (Tampak Atas Abstrak)
          _buildAnimatedBackground(),

          SafeArea(child: _buildBody()),
        ],
      ),),
      bottomNavigationBar: FloatingBottomBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
          if (index == 1) Navigator.pushReplacementNamed(context, '/record');
        },
        isSmall: false,
      ),
    );
  }

  // WIDGET BARU: Latar Belakang Animasi
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        // Nilai animasi antara 0.0 sampai 1.0, digunakan untuk mengubah parameter
        final value = _bgAnimController.value;
        final scaleFactor = 1.0 + (value * 0.1); // Skala 1.0 hingga 1.1
        final rotation = math.pi * value * 0.05; // Rotasi kecil

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 350, // Ketinggian pola diperbesar
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scaleFactor,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      // Warna yang lebih kontras agar terlihat
                      primaryColor.withValues(alpha: 0.15),
                      darkBgColor.withValues(alpha: 0.0),
                    ],
                    center: const Alignment(0.5, -0.5), // Posisikan lebih tinggi
                    radius: 0.9,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  /// Widget untuk body - menampilkan loading, empty state, atau list
  Widget _buildBody() {
    // Tampilkan loading spinner saat data sedang diambil
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor, // Menggunakan warna tema
        ),
      );
    }

    // Tampilkan empty state jika tidak ada data
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pool_outlined,
              size: 80,
              color: lightTextColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No swimming activities yet',
              style: TextStyle(
                color: lightTextColor.withValues(alpha: 0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start recording your swim sessions!',
              style: TextStyle(
                color: lightTextColor.withValues(alpha: 0.4),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/record'),
              icon: const Icon(Icons.add_circle, color: lightTextColor),
              label: const Text('Start Recording', style: TextStyle(color: lightTextColor, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          ],
        ),
      );
    }

    // Tampilkan list activities dengan animasi
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: loadActivitiesFromDatabase,
      color: primaryColor,
      child: ListView.builder(
        // Padding atas yang memadai agar konten tidak tertutup pola abstrak
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 100.0),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          return AnimatedHistoryCard(
            activity: activities[index],
            index: index,
          );
        },
      ),
    );
  }
}

// =========================================================================
// WIDGET-WIDGET PENDUKUNG (Tidak diubah, hanya dipindahkan ke bawah)
// =========================================================================

/// Widget untuk animasi staggered list
class AnimatedHistoryCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final int index;

  const AnimatedHistoryCard({
    super.key,
    required this.activity,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _HistoryCard(activity: activity),
    );
  }
}

/// Widget yang berisi konten card history
class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _HistoryCard({required this.activity});

  // Helper function: Get title berdasarkan swimming style
  String _getActivityTitle(String style) {
    switch (style.toLowerCase()) {
      case 'freestyle':
        return 'Freestyle Session';
      case 'breaststroke':
        return 'Breaststroke Practice';
      case 'backstroke':
        return 'Backstroke Training';
      case 'butterfly':
        return 'Butterfly Workout';
      case 'mixed':
        return 'Mixed Style Session';
      default:
        return 'Swimming Session';
    }
  }

  // Helper function: Format nama style
  String _formatStyleName(String style) {
    if (style.isEmpty) return 'Mixed';
    return style[0].toUpperCase() + style.substring(1).toLowerCase();
  }

  // Helper function: Get color berdasarkan swimming style
  Color _getStyleColor(String style) {
    switch (style.toLowerCase()) {
      case 'freestyle':
        return primaryColor;
      case 'breaststroke':
        return const Color(0xFF4CAF50); // Green
      case 'backstroke':
        return const Color(0xFFAB47BC); // Purple
      case 'butterfly':
        return const Color(0xFFFF9800); // Orange
      case 'mixed':
        return accentColor;
      default:
        return primaryColor;
    }
  }

  Widget _buildStyleBadge(String style) {
    final styleColor = _getStyleColor(style);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: styleColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: styleColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        _formatStyleName(style),
        style: TextStyle(
          color: styleColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: lightTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.parse(activity['timestamp']);
    final totalDistance = activity['total_distance'] ?? 0;
    final totalTime = activity['total_time'] ?? '00:00:00';
    final pace = activity['pace'] ?? '00:00:00';
    final swimmingStyle = activity['swimming_style'] ?? 'Mixed';
    final activityId = activity['id_activity'];
    final activityTitle = activity['activity_title'];
    final activityNotes = activity['activity_notes'];

    final distanceInKm = (totalDistance / 1000).toStringAsFixed(1);
    final timeParts = totalTime.split(':');
    final formattedTime = '${timeParts[0]}h ${timeParts[1]}m';

    final paceParts = pace.split(':');
    final formattedPace = '${paceParts[1]}m ${paceParts[2]}s / 100m';


    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/history-detail',
          arguments: activityId,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        decoration: BoxDecoration(
          color: darkCardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(timestamp),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  _buildStyleBadge(swimmingStyle),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                activityTitle != null && activityTitle.toString().isNotEmpty
                    ? activityTitle
                    : _getActivityTitle(swimmingStyle),
                style: const TextStyle(
                  color: lightTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (activityNotes != null && activityNotes.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  activityNotes,
                  style: TextStyle(
                    color: lightTextColor.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),

              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn("Distance", "$distanceInKm km"),
                  _buildStatColumn("Time", formattedTime),
                  _buildStatColumn("Pace", formattedPace),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}