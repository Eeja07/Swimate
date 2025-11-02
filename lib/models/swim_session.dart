// lib/models/swim_session.dart

class SwimSession {
  final DateTime timestamp;
  final String title;
  final String distance;
  final String time;
  final String pace;
  final String style;

  SwimSession({
    required this.timestamp,
    required this.title,
    required this.distance,
    required this.time,
    required this.pace,
    required this.style,
  });
}
