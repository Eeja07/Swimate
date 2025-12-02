import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/wave_background.dart';


class AppBreakpoints {
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
}
// ----------------------------------------------------------------------------------------

// --- Konstanta Warna Tema ---
const Color primaryColor = Color(0xFF1976D2);
const Color accentColor = Color(0xFF4FC3F7);
const Color lightTextColor = Colors.white;
const Color darkBgColor = Color(0xFF0A1628);
const Color cardBgColor = Color(0xFF162B44);


class HistoryDetailPage extends StatefulWidget {
  final String? activityId;

  const HistoryDetailPage({
    super.key,
    this.activityId,
  });

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final logger = Logger();

  String? get currentUserId => supabase.auth.currentUser?.id;

  Map<String, dynamic>? activityData;
  List<dynamic> segments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        loadActivityData(args);
      } else if (widget.activityId != null) {
        loadActivityData(widget.activityId!);
      }
    });
  }

  Future<void> loadActivityData(String activityId) async {
    if (currentUserId == null) {
      logger.e('User not authenticated when loading activity data.');
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final activity = await supabase
          .from('activity_table')
          .select()
          .eq('id_activity', activityId)
          .eq('id_user', currentUserId!)
          .single();

      final activitySegments = await supabase
          .from('activity_segments')
          .select()
          .eq('id_activity', activityId)
          .order('seq');

      setState(() {
        activityData = activity;
        segments = activitySegments;
        isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading activity data', error: e);
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatTotalTime(String totalTime) {
    final parts = totalTime.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;

    String result = '';
    if (h > 0) result += '${h}h ';
    if (m > 0 || h > 0) result += '${m.toString().padLeft(2, '0')}m ';
    result += '${s.toString().padLeft(2, '0')}s';

    return result.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: darkBgColor,
        appBar: CustomNavbar(title: "Loading...", showBackButton: true),
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    if (activityData == null) {
      return Scaffold(
        backgroundColor: darkBgColor,
        appBar: const CustomNavbar(title: "Activity Detail", showBackButton: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'No activity data found',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                ),
                child: const Text('Go Back', style: TextStyle(color: lightTextColor)),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ IMPLEMENTASI AKHIR: Menggunakan CustomNavbar dan WaveBackground
    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: const CustomNavbar(
        title: "Activity Detail",
        showBackButton: true,
      ),
      body: WaveBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildTitleAndDate(),
                        const SizedBox(height: 24),

                        _buildDistanceBreakdown(),
                        const SizedBox(height: 24),

                        _buildOverallStatistics(context),
                        const SizedBox(height: 24),

                        if (segments.isNotEmpty) _buildSegmentsDetail(),
                        if (segments.isNotEmpty) const SizedBox(height: 24),

                        if (_hasNotes()) _buildNotes(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getActivityTitle(),
          style: const TextStyle(
            color: lightTextColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            const Icon(Icons.calendar_today,
                color: primaryColor, size: 16),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMMM yyyy').format(
                  DateTime.parse(activityData!['timestamp'])
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(width: 20),
            const Icon(Icons.access_time,
                color: primaryColor, size: 16),
            const SizedBox(width: 8),
            Text(
              DateFormat('HH:mm').format(
                  DateTime.parse(activityData!['start_time'])
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }

  String _getActivityTitle() {
    final title = activityData!['activity_title'];
    if (title != null && title.toString().isNotEmpty) {
      return title;
    }

    final style = activityData!['swimming_style'] ?? 'Mixed';
    return '${_getStrokeName(style)} Session';
  }

  bool _hasNotes() {
    final notes = activityData!['activity_notes'];
    return notes != null && notes.toString().isNotEmpty;
  }

  Widget _buildDistanceBreakdown() {
    final totalDistance = activityData!['total_distance'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distance Breakdown',
            style: TextStyle(
              color: lightTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 25,
            child: Row(
              children: segments.map((segment) {
                final distance = segment['distance'] as int;
                if (distance == 0) return const SizedBox.shrink();

                return Expanded(
                  flex: distance,
                  child: Tooltip(
                    message: '${_getStrokeName(segment['style'])}: ${distance}m',
                    child: Container(
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: _getStrokeColor(segment['style']),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          distance > totalDistance * 0.1 ? '${distance}m' : '',
                          style: const TextStyle(
                            color: lightTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0m', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                '$totalDistance m',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: _getUniqueStrokes().map((style) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStrokeColor(style),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStrokeName(style),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ✅ Responsif: _buildOverallStatistics menggunakan responsivitas AppBreakpoints
  Widget _buildOverallStatistics(BuildContext context) {
    final totalDistanceKm = (activityData!['total_distance'] / 1000).toStringAsFixed(2);
    final formattedTime = _formatTotalTime(activityData!['total_time'] as String);
    final pace = activityData!['pace'] as String;

    final stats = [
      {'label': 'TOTAL DISTANCE', 'value': '$totalDistanceKm km', 'icon': Icons.directions_run},
      {'label': 'TOTAL TIME', 'value': formattedTime, 'icon': Icons.access_time_filled},
      {'label': 'AVERAGE PACE (100m)', 'value': pace.substring(3), 'icon': Icons.speed},
      {'label': 'TOTAL STROKES', 'value': '${activityData!['total_strokes']}', 'icon': Icons.rowing},
      {'label': 'CALORIES BURNED', 'value': '${activityData!['calories']} kcal', 'icon': Icons.local_fire_department},
      {'label': 'CONFIDENCE', 'value': '${(activityData!['confidence'] * 100).toStringAsFixed(0)}%', 'icon': Icons.check_circle_outline},
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    // Tentukan jumlah kolom: 3 kolom jika lebar >= AppBreakpoints.lg (1024), jika tidak 2 kolom.
    final columns = screenWidth >= AppBreakpoints.lg ? 3 : 2;

    List<Widget> columnWidgets = [];

    if (columns == 3) {
      // 3 Kolom: 2 item per kolom
      final column1 = stats.sublist(0, 2);
      final column2 = stats.sublist(2, 4);
      final column3 = stats.sublist(4, 6);

      columnWidgets = [
        Expanded(child: Column(children: column1.map((item) => _buildStatItem(item['label'] as String, item['value'] as String, item['icon'] as IconData)).toList())),
        const SizedBox(width: 16),
        Expanded(child: Column(children: column2.map((item) => _buildStatItem(item['label'] as String, item['value'] as String, item['icon'] as IconData)).toList())),
        const SizedBox(width: 16),
        Expanded(child: Column(children: column3.map((item) => _buildStatItem(item['label'] as String, item['value'] as String, item['icon'] as IconData)).toList())),
      ];

    } else {
      // 2 Kolom: 3 item per kolom (tampilan default)
      final column1 = stats.sublist(0, 3);
      final column2 = stats.sublist(3);

      columnWidgets = [
        Expanded(child: Column(children: column1.map((item) => _buildStatItem(item['label'] as String, item['value'] as String, item['icon'] as IconData)).toList())),
        const SizedBox(width: 16),
        Expanded(child: Column(children: column2.map((item) => _buildStatItem(item['label'] as String, item['value'] as String, item['icon'] as IconData)).toList())),
      ];
    }

    // Final Layout
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Statistics',
            style: TextStyle(
              color: lightTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: lightTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsDetail() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Segments',
            style: TextStyle(
              color: lightTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ...segments.map((segment) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStrokeColor(segment['style']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getStrokeName(segment['style']),
                      style: const TextStyle(
                        color: lightTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${segment['distance']}m (${_formatTotalTime(segment['segment_time'])})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    final notes = activityData!['activity_notes'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.note_outlined, color: primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  color: lightTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notes ?? 'No notes available',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStrokeColor(String style) {
    switch (style.toLowerCase()) {
      case 'breaststroke':
        return const Color(0xFF4CAF50);
      case 'butterfly':
        return const Color(0xFFFF9800);
      case 'freestyle':
        return primaryColor;
      case 'backstroke':
        return const Color(0xFFAB47BC);
      default:
        return Colors.grey;
    }
  }

  String _getStrokeName(String style) {
    if (style.isEmpty) return 'Unknown';
    return style[0].toUpperCase() + style.substring(1);
  }

  List<String> _getUniqueStrokes() {
    final strokes = segments.map((s) => s['style'] as String).toSet().toList();
    return strokes;
  }
}