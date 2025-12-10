import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/fa_solid.dart';
import 'package:iconify_flutter/icons/ep.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/animated_result_dialog.dart';

// --- Konstanta Warna ---
const Color primaryColor = Color(0xFF1976D2);
const Color lightTextColor = Colors.white;
const Color accentColor = Color(0xFF4FC3F7);
const Color darkOverlayColor = Color(0xB3000000);
const Color cardBgColor = Color(0xCC1E1E1E);
const Color fieldFillColor = Color(0xDDFFFFFF);

class ConfirmActivityPage extends StatefulWidget {
  final int durationSeconds;
  final double distance;
  final int strokes;
  final List<Map<String, dynamic>>? sensorData;
  final List<Map<String, dynamic>>? segments;
  final String? detectedStyle;
  final double? styleConfidence;

  const ConfirmActivityPage({
    super.key,
    required this.durationSeconds,
    required this.distance,
    required this.strokes,
    this.sensorData,
    this.segments,
    this.detectedStyle,
    this.styleConfidence,
  });

  @override
  State<ConfirmActivityPage> createState() => _ConfirmActivityPageState();
}

class _ConfirmActivityPageState extends State<ConfirmActivityPage> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Swimming Session',
  );
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;
  String? _selectedStyle;

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.detectedStyle;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    return '${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        await AnimatedResultDialog.show(
          context: context,
          isSuccess: false,
          title: 'Authentication Required',
          message: 'Please sign in to continue',
          onClose: () {
            Navigator.pushReplacementNamed(context, '/signin');
          },
        );
        return;
      }

      final now = DateTime.now();
      final startTime = now.subtract(Duration(seconds: widget.durationSeconds));

      final totalTimeInterval = _formatInterval(widget.durationSeconds);
      final paceInterval = _calculatePaceInterval();

      final primaryStyle = widget.segments != null && widget.segments!.isNotEmpty
          ? _determinePrimaryStyle()
          : (_selectedStyle ?? 'freestyle');

      final activityPayload = {
        'id_user': user.id,
        'total_distance': widget.distance.round(),
        'total_time': totalTimeInterval,
        'swimming_style': primaryStyle,
        'confidence': widget.styleConfidence ?? 0.85,
        'calories': _calculateCalories(),
        'timestamp': now.toIso8601String(),
        'start_time': startTime.toIso8601String(),
        'end_time': now.toIso8601String(),
        'total_strokes': widget.strokes,
        'pace': paceInterval,
        'activity_title': _titleController.text.trim(),
        'activity_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      final activityResponse = await supabase
          .from('activity_table')
          .insert(activityPayload)
          .select('id_activity')
          .single();

      final activityId = activityResponse['id_activity'] as String;

      // Insert segments dengan style yang benar
      if (widget.segments != null && widget.segments!.isNotEmpty) {
        await _insertSegments(activityId);
      }

      if (mounted) {
        await AnimatedResultDialog.show(
          context: context,
          isSuccess: true,
          title: 'Success!',
          message: 'Activity submitted successfully!',
          autoCloseDuration: const Duration(seconds: 2),
          onClose: () {
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
        );
      }
    } catch (e, st) {
      debugPrint('Error submitting activity: $e\n$st');
      if (mounted) {
        await AnimatedResultDialog.show(
          context: context,
          isSuccess: false,
          title: 'Error',
          message: 'Failed to submit activity. Please try again.',
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _insertSegments(String activityId) async {
    final segmentsList = <Map<String, dynamic>>[];

    int totalDistance = 0;
    int totalStrokes = 0;

    for (var i = 0; i < widget.segments!.length; i++) {
      final segment = widget.segments![i];
      final segmentDuration = segment['duration'] as int;
      
      // Ambil style dari segment, atau gunakan detected style, atau default freestyle
      final segmentStyle = segment['style']?.toString().toLowerCase() ?? 
                          widget.detectedStyle?.toLowerCase() ?? 
                          'freestyle';

      final distanceProportion = segmentDuration / widget.durationSeconds;
      final segmentDistance = (widget.distance * distanceProportion).round();
      final segmentStrokes = (widget.strokes * distanceProportion).round();

      totalDistance += segmentDistance;
      totalStrokes += segmentStrokes;

      final isLastSegment = i == widget.segments!.length - 1;
      final adjustedDistance = isLastSegment
          ? segmentDistance + (widget.distance.round() - totalDistance)
          : segmentDistance;
      final adjustedStrokes = isLastSegment
          ? segmentStrokes + (widget.strokes - totalStrokes)
          : segmentStrokes;

      final segmentTimeInterval = _formatInterval(segmentDuration);

      segmentsList.add({
        'id_activity': activityId,
        'seq': i + 1,
        'style': segmentStyle, // Pastikan style tersimpan dengan benar
        'distance': adjustedDistance,
        'strokes': adjustedStrokes,
        'segment_time': segmentTimeInterval,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (segmentsList.isNotEmpty) {
      await supabase.from('activity_segments').insert(segmentsList);
      debugPrint('Inserted ${segmentsList.length} segments with styles');
    }
  }

  String _formatInterval(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  String _determinePrimaryStyle() {
    if (widget.segments == null || widget.segments!.isEmpty) {
      return _selectedStyle ?? 'freestyle';
    }

    // Hitung durasi total per style
    final Map<String, int> styleDurations = {};
    
    for (var segment in widget.segments!) {
      final style = segment['style']?.toString().toLowerCase() ?? 'freestyle';
      final duration = segment['duration'] as int;
      styleDurations[style] = (styleDurations[style] ?? 0) + duration;
    }

    // Jika hanya ada 1 style, return style tersebut
    if (styleDurations.length == 1) {
      return styleDurations.keys.first;
    }

    // Jika lebih dari 1 style, return 'Mixed'
    if (styleDurations.length > 1) {
      return 'Mixed';
    }

    return _selectedStyle ?? 'freestyle';
  }

  int _calculateCalories() {
    final minutes = widget.durationSeconds / 60;
    return (minutes * 11).round();
  }

  String _calculatePaceInterval() {
    if (widget.distance <= 0) return "00:00:00";

    final secondsPer100m = (widget.durationSeconds / widget.distance) * 100;
    final hours = (secondsPer100m ~/ 3600);
    final minutes = ((secondsPer100m % 3600) ~/ 60);
    final seconds = (secondsPer100m % 60).round();

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: _submitting ? null : () => Navigator.pushReplacementNamed(context, '/record'),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Iconify(Ep.arrow_left_bold, color: lightTextColor, size: 26),
          ),
        ),
        title: const Text('Confirm Activity', style: TextStyle(color: lightTextColor)),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/signup.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: darkOverlayColor,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                        child: const Iconify(
                          FaSolid.swimmer,
                          color: primaryColor,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Title (ex: Training Endurance)',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(Icons.title, color: primaryColor),
                        filled: true,
                        fillColor: fieldFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Duration', _formatDuration(widget.durationSeconds)),
                        _buildStatColumn('Distance', '${widget.distance.toStringAsFixed(0)} m'),
                        _buildStatColumn('Strokes', '${widget.strokes}'),
                      ],
                    ),

                    if (widget.segments != null && widget.segments!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Swimming Segments',
                        style: TextStyle(
                          color: lightTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.segments!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final segment = entry.value;
                        final style = segment['style']?.toString() ?? 'Unknown';
                        final duration = segment['duration'] as int;
                        
                        // Hitung distance untuk segment ini
                        final distanceProportion = duration / widget.durationSeconds;
                        final segmentDistance = (widget.distance * distanceProportion).round();
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                          decoration: BoxDecoration(
                            color: _getStyleColor(style).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _getStyleColor(style).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getStyleColor(style),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    style.toUpperCase(),
                                    style: const TextStyle(
                                      color: lightTextColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '${segmentDistance}m',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 24),

                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Notes (optional)',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(Icons.note, color: primaryColor),
                        filled: true,
                        fillColor: fieldFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: lightTextColor,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: lightTextColor,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting ? null : () => Navigator.pushReplacementNamed(context, '/record'),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: lightTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: lightTextColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // Helper function untuk mendapatkan warna berdasarkan style
  Color _getStyleColor(String style) {
    switch (style.toLowerCase()) {
      case 'freestyle':
        return Colors.blue;
      case 'backstroke':
        return Colors.purple;
      case 'breaststroke':
        return Colors.green;
      case 'butterfly':
        return Colors.orange;
      case 'not swimming':
      case 'notswimming':
      case 'rest':
      case 'idle':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}