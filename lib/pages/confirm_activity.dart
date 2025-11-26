import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/fa_solid.dart';
import 'package:iconify_flutter/icons/ep.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmActivityPage extends StatefulWidget {
  final int durationSeconds;
  final double distance;
  final int strokes;
  final List<Map<String, dynamic>>? sensorData;
  final List<Map<String, dynamic>>? segments;

  const ConfirmActivityPage({
    super.key,
    required this.durationSeconds,
    required this.distance,
    required this.strokes,
    this.sensorData,
    this.segments,
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

  SupabaseClient get supabase => Supabase.instance.client;

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
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not authenticated'))
          );
          Navigator.pushReplacementNamed(context, '/signin');
        }
        return;
      }

      final now = DateTime.now();
      final startTime = now.subtract(Duration(seconds: widget.durationSeconds));

      // Format INTERVAL untuk PostgreSQL (HH:MM:SS)
      final totalTimeInterval = _formatInterval(widget.durationSeconds);
      final paceInterval = _calculatePaceInterval();

      // 1. Insert ke tabel activity_table
      final activityPayload = {
        'id_user': user.id,
        'total_distance': widget.distance.round(), // INT8
        'total_time': totalTimeInterval, // INTERVAL as 'HH:MM:SS'
        'swimming_style': _determinePrimaryStyle(), // TEXT
        'confidence': 0.85, // NUMERIC (double)
        'calories': _calculateCalories(), // INT8
        'timestamp': now.toIso8601String(), // TIMESTAMPTZ
        'start_time': startTime.toIso8601String(), // TIMESTAMPTZ
        'end_time': now.toIso8601String(), // TIMESTAMPTZ
        'total_strokes': widget.strokes, // INT8
        'pace': paceInterval, // INTERVAL as 'HH:MM:SS'
        'activity_title': _titleController.text.trim(), // TEXT
        'activity_notes': _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(), // TEXT (nullable)
      };

      final activityResponse = await supabase
          .from('activity_table')
          .insert(activityPayload)
          .select('id_activity')
          .single();

      final activityId = activityResponse['id_activity'] as String;

      // 2. Insert segments ke tabel activity_segments
      if (widget.segments != null && widget.segments!.isNotEmpty) {
        await _insertSegments(activityId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity submitted successfully!'))
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e, st) {
      debugPrint('Error submitting activity: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
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
      
      // Hitung proporsi distance dan strokes untuk segment ini
      final distanceProportion = segmentDuration / widget.durationSeconds;
      final segmentDistance = (widget.distance * distanceProportion).round();
      final segmentStrokes = (widget.strokes * distanceProportion).round();
      
      totalDistance += segmentDistance;
      totalStrokes += segmentStrokes;
      
      // Adjust terakhir jika ada selisih pembulatan
      final isLastSegment = i == widget.segments!.length - 1;
      final adjustedDistance = isLastSegment 
          ? segmentDistance + (widget.distance.round() - totalDistance)
          : segmentDistance;
      final adjustedStrokes = isLastSegment
          ? segmentStrokes + (widget.strokes - totalStrokes)
          : segmentStrokes;

      // Format segment_time sebagai INTERVAL (HH:MM:SS)
      final segmentTimeInterval = _formatInterval(segmentDuration);

      segmentsList.add({
        'id_activity': activityId, // UUID
        'seq': i + 1, // INT4
        'style': segment['style'], // TEXT
        'distance': adjustedDistance, // INT8
        'strokes': adjustedStrokes, // INT8
        'segment_time': segmentTimeInterval, // INTERVAL as 'HH:MM:SS'
        'created_at': DateTime.now().toIso8601String(), // TIMESTAMPTZ
      });
    }

    if (segmentsList.isNotEmpty) {
      await supabase.from('activity_segments').insert(segmentsList);
    }
  }

  // Format durasi dalam detik ke PostgreSQL INTERVAL format (HH:MM:SS)
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
      return 'freestyle';
    }

    // Jika ada lebih dari 1 style berbeda, return "Mixed"
    final uniqueStyles = widget.segments!.map((s) => s['style'] as String).toSet();
    if (uniqueStyles.length > 1) {
      return 'Mixed';
    }

    // Jika hanya 1 style, return style tersebut
    return uniqueStyles.first;
  }

  int _calculateCalories() {
    // Formula sederhana: durasi (menit) * 11 kalori/menit (rata-rata swimming)
    final minutes = widget.durationSeconds / 60;
    return (minutes * 11).round();
  }

  String _calculatePaceInterval() {
    // Pace dalam format INTERVAL "HH:MM:SS" per 100m
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Iconify(Ep.arrow_left_bold, color: Colors.white, size: 26),
          ),
        ),
        title: const Text('Confirm Activity'),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/signup.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x80000000),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white24,
                      child: const Iconify(
                        FaSolid.swimmer,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Title',
                      prefixIcon: Icon(Icons.edit, color: Colors.grey[700]),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duration',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDuration(widget.durationSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Distance',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.distance.toStringAsFixed(1)} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Strokes',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.strokes}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Tampilkan segments jika ada
                  if (widget.segments != null && widget.segments!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Swimming Styles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.segments!.map((segment) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            segment['style'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(segment['duration'] as int),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )),
                  ],
                  
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.note, color: Colors.grey[700]),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}