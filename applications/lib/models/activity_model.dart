class ActivityModel {
  final String idActivity;
  final int totalDistance;
  final Duration totalTime;
  final String swimmingStyle;
  final int totalStrokes;
  final Duration pace;
  final DateTime timestamp;
  final double? styleConfidence; // ML model confidence score
  final String? detectedStyle; // Original ML detected style before user override

  ActivityModel({
    required this.idActivity,
    required this.totalDistance,
    required this.totalTime,
    required this.swimmingStyle,
    required this.totalStrokes,
    required this.pace,
    required this.timestamp,
    this.styleConfidence,
    this.detectedStyle,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      idActivity: json['id_activity'],
      totalDistance: json['total_distance'] ?? 0,
      totalTime: _parseDuration(json['total_time']),
      swimmingStyle: json['swimming_style'] ?? '',
      totalStrokes: json['total_strokes'] ?? 0,
      pace: _parseDuration(json['pace']),
      timestamp: DateTime.parse(json['timestamp']),
      styleConfidence: json['style_confidence']?.toDouble(),
      detectedStyle: json['detected_style'],
    );
  }

  static Duration _parseDuration(dynamic value) {
    if (value == null) return Duration.zero;
    if (value is String) {
      // Parse PostgreSQL interval format (e.g., "00:45:00")
      final parts = value.split(':');
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2].split('.')[0]),
        );
      }
    }
    return Duration.zero;
  }

  // Helper untuk format distance
  String get formattedDistance {
    return '${(totalDistance / 1000).toStringAsFixed(1)} km';
  }

  // Helper untuk format pace (per 100m)
  String get formattedPace {
    if (totalDistance == 0) return '0:00 /100m';
    final pacePerMeter = totalTime.inSeconds / totalDistance;
    final pacePer100m = pacePerMeter * 100;
    final minutes = (pacePer100m / 60).floor();
    final seconds = (pacePer100m % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /100m';
  }

  // Helper untuk format total time
  String get formattedTotalTime {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    if (hours > 0) {
      return '$hours h $minutes min';
    }
    return '$minutes min';
  }

  // Helper untuk format strokes
  String get formattedStrokes {
    return totalStrokes.toString();
  }
}