// pages/history_detail.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

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
    // Get activityId from arguments if not provided via constructor
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
    try {
      // Load specific activity data by ID
      final activity = await supabase
          .from('activity_table')
          .select()
          .eq('id_activity', activityId)
          .eq('id_user', currentUserId!)
          .single();

      // Load segments for this activity
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1628),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2196F3),
          ),
        ),
      );
    }

    if (activityData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1628),
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
                  backgroundColor: const Color(0xFF2196F3),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title - ambil dari activity_title atau gunakan default
                      Text(
                        _getActivityTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Date and time
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, 
                            color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(
                              DateTime.parse(activityData!['timestamp'])
                            ),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 24),
                          const Icon(Icons.access_time, 
                            color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(
                              DateTime.parse(activityData!['start_time'])
                            ),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Distance Breakdown
                      _buildDistanceBreakdown(),
                      const SizedBox(height: 24),
                      
                      // Overall Statistics
                      _buildOverallStatistics(),
                      const SizedBox(height: 24),
                      
                      // Notes - hanya tampilkan jika ada
                      if (_hasNotes()) _buildNotes(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper untuk mendapatkan activity title
  String _getActivityTitle() {
    final title = activityData!['activity_title'];
    if (title != null && title.toString().isNotEmpty) {
      return title;
    }
    
    // Fallback ke title berdasarkan swimming style
    final style = activityData!['swimming_style'] ?? 'Mixed';
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

  // Helper untuk mengecek apakah ada notes
  bool _hasNotes() {
    final notes = activityData!['activity_notes'];
    return notes != null && notes.toString().isNotEmpty;
  }

  Widget _buildDistanceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distance Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Progress bar
          SizedBox(
            height: 40,
            child: Stack(
              children: [
                Row(
                  children: segments.map((segment) {
                    return Expanded(
                      flex: segment['distance'] as int,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: _getStrokeColor(segment['style']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${segment['distance']} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Distance labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0m', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${activityData!['total_distance'] / 1000} km',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _getUniqueStrokes().map((style) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _getStrokeColor(style),
                      borderRadius: BorderRadius.circular(4),
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

  Widget _buildOverallStatistics() {
    final totalTime = activityData!['total_time'] as String;
    final parts = totalTime.split(':');
    final formattedTime = '${parts[0]}:${parts[1]}';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL DISTANCE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activityData!['total_distance'] / 1000} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'AVERAGE PACE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activityData!['pace'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CALORIES BURNED',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activityData!['calories']} kcal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL TIME',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TOTAL STROKES',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activityData!['total_strokes']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    final notes = activityData!['activity_notes'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.note_outlined, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  color: Colors.white,
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
              fontSize: 14,
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
        return const Color(0xFF2196F3);
      case 'backstroke':
        return const Color(0xFFAB47BC);
      default:
        return Colors.grey;
    }
  }

  String _getStrokeName(String style) {
    return style[0].toUpperCase() + style.substring(1);
  }

  List<String> _getUniqueStrokes() {
    final strokes = segments.map((s) => s['style'] as String).toSet().toList();
    return strokes;
  }
}