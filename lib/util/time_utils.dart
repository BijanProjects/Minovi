import 'package:intl/intl.dart';

/// Time formatting utilities matching the Kotlin TimeUtils.
abstract final class TimeUtils {
  /// Format "HH:mm" → "h:mm a" (12-hour)
  static String formatTime(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(dt);
  }

  /// Format time range: "7:00 AM — 9:00 AM"
  static String formatTimeRange(String start, String end) {
    return '${formatTime(start)} — ${formatTime(end)}';
  }

  /// Format date label: "Today", "Yesterday", "Tomorrow", or "EEE, MMM d"
  static String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(date);
  }

  /// Format interval label: "30m", "1h", "1h30", "2h", "3h", "4h"
  static String formatIntervalLabel(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h$m';
  }

  /// Format ISO date string from DateTime.
  static String toIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Parse time string "HH:mm" to minutes since midnight.
  static int timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
