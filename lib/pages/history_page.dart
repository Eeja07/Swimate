// pages/history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/floating_bottom_bar.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Inisialisasi Supabase client dan logger
  final SupabaseClient supabase = Supabase.instance.client;
  final logger = Logger();
  
  // Getter untuk mendapatkan user ID yang sedang login
  String? get currentUserId => supabase.auth.currentUser?.id;
  
  // List untuk menyimpan data activities dari database
  List<Map<String, dynamic>> activities = [];
  
  // Variable untuk tracking loading state
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load data saat page pertama kali dibuka
    loadActivitiesFromDatabase();
  }

  /// Fungsi untuk mengambil semua activities user dari database
  Future<void> loadActivitiesFromDatabase() async {
    try {
      // Set loading state
      setState(() {
        isLoading = true;
      });

      // Query ke database Supabase
      // Mengambil data dari tabel activity_table
      // Filter berdasarkan id_user (hanya ambil data user yang login)
      // Urutkan dari yang terbaru (descending)
      final response = await supabase
          .from('activity_table')
          .select()
          .eq('id_user', currentUserId!)
          .order('timestamp', ascending: false);

      // Update state dengan data yang didapat
      setState(() {
        activities = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      logger.i('✅ Loaded ${activities.length} activities');
    } catch (e) {
      // Jika terjadi error, log dan update state
      logger.e('❌ Error loading activities', error: e);
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomNavbar(
        title: "History",
        showBackButton: false,
      ),
      body: _buildBody(),
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

  /// Widget untuk body - menampilkan loading, empty state, atau list
  Widget _buildBody() {
    // Tampilkan loading spinner saat data sedang diambil
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
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
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No swimming activities yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start recording your swim sessions!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Tampilkan list activities
    return RefreshIndicator(
      onRefresh: loadActivitiesFromDatabase,
      color: Colors.blueAccent,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(activities[index]);
        },
      ),
    );
  }

  /// Widget untuk membuat card history
  Widget _buildHistoryCard(Map<String, dynamic> activity) {
    // Parse data dari database
    final timestamp = DateTime.parse(activity['timestamp']);
    final totalDistance = activity['total_distance'] ?? 0; // dalam meter
    final totalTime = activity['total_time'] ?? '00:00:00'; // format HH:MM:SS
    final pace = activity['pace'] ?? '0:00/100m';
    final swimmingStyle = activity['swimming_style'] ?? 'Mixed';
    final activityId = activity['id_activity'];
    
    // Ambil activity_title dan activity_notes dari database
    final activityTitle = activity['activity_title'];
    final activityNotes = activity['activity_notes'];

    // Format distance (konversi dari meter ke km)
    final distanceInKm = (totalDistance / 1000).toStringAsFixed(1);
    
    // Format time (ambil HH:MM saja, buang detik)
    final timeParts = totalTime.split(':');
    final formattedTime = '${timeParts[0]}:${timeParts[1]}';

    return GestureDetector(
      // Navigasi ke detail page saat card diklik
      onTap: () {
        logger.i('Opening detail for activity: $activityId');
        Navigator.pushNamed(
          context,
          '/history-detail',
          arguments: activityId,
        );
      },
      child: Card(
        color: const Color(0xFF1C1C1E),
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris 1: Timestamp dan Swimming Style Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(timestamp),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  _buildStyleBadge(swimmingStyle),
                ],
              ),
              const SizedBox(height: 8),

              // Baris 2: Title (gunakan activity_title jika ada, jika tidak gunakan default)
              Text(
                activityTitle != null && activityTitle.toString().isNotEmpty
                    ? activityTitle
                    : _getActivityTitle(swimmingStyle),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Tampilkan notes jika ada
              if (activityNotes != null && activityNotes.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  activityNotes,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 16),

              // Divider
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),

              // Baris 3: Stats (Distance, Time, Pace)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn("Distance", "$distanceInKm km"),
                  _buildStatColumn("Time", formattedTime),
                  _buildStatColumn("Pace", pace),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget untuk badge swimming style
  Widget _buildStyleBadge(String style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStyleColor(style).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatStyleName(style),
        style: TextStyle(
          color: _getStyleColor(style),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Widget untuk kolom statistik
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
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Helper function: Get title berdasarkan swimming style
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

  /// Helper function: Format nama style
  String _formatStyleName(String style) {
    if (style.isEmpty) return 'Mixed';
    return style[0].toUpperCase() + style.substring(1).toLowerCase();
  }

  /// Helper function: Get color berdasarkan swimming style
  Color _getStyleColor(String style) {
    switch (style.toLowerCase()) {
      case 'freestyle':
        return const Color(0xFF2196F3); // Blue
      case 'breaststroke':
        return const Color(0xFF4CAF50); // Green
      case 'backstroke':
        return const Color(0xFFAB47BC); // Purple
      case 'butterfly':
        return const Color(0xFFFF9800); // Orange
      case 'mixed':
        return Colors.blueAccent;
      default:
        return Colors.blueAccent;
    }
  }
}