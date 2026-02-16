import 'package:chronosense/domain/model/models.dart';

/// Stateless, O(S + E·logE) interval engine.
/// Generates time slots, finds active slot index, computes next notification time.
class IntervalEngine {
  const IntervalEngine._();

  /// Generate time slots for a day based on preferences,
  /// then overlay any matching journal entries.
  static List<TimeSlot> generateSlots({
    required UserPreferences prefs,
    required List<JournalEntry> entries,
  }) {
    final slots = <TimeSlot>[];
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final sleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final interval = prefs.intervalMinutes;

    // Build entry lookup by startTime for O(1) matching
    final entryMap = <String, JournalEntry>{};
    for (final entry in entries) {
      entryMap[entry.startTime] = entry;
    }

    int current = wakeMin;
    while (current + interval <= sleepMin) {
      final startH = current ~/ 60;
      final startM = current % 60;
      final endMin = current + interval;
      final endH = endMin ~/ 60;
      final endM = endMin % 60;

      final startTimeStr =
          '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
      final endTimeStr =
          '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

      slots.add(TimeSlot(
        startTime: startTimeStr,
        endTime: endTimeStr,
        entry: entryMap[startTimeStr],
      ));

      current = endMin;
    }

    return slots;
  }

  /// Find the index of the currently-active time slot, or -1.
  static int findActiveSlotIndex(List<TimeSlot> slots, DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    for (int i = 0; i < slots.length; i++) {
      final parts = slots[i].startTime.split(':');
      final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final eParts = slots[i].endTime.split(':');
      final endMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      if (nowMin >= startMin && nowMin < endMin) {
        return i;
      }
    }
    return -1;
  }

  /// Compute the next notification time (slot boundary) from now.
  static DateTime? nextNotificationTime({
    required UserPreferences prefs,
    required DateTime now,
  }) {
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final sleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final interval = prefs.intervalMinutes;
    final nowMin = now.hour * 60 + now.minute;

    int boundary = wakeMin + interval;
    while (boundary <= sleepMin) {
      if (boundary > nowMin) {
        return DateTime(now.year, now.month, now.day, boundary ~/ 60, boundary % 60);
      }
      boundary += interval;
    }
    return null;
  }

  /// Get all remaining slot boundary times for today (for scheduling notifications).
  static List<DateTime> remainingBoundaries({
    required UserPreferences prefs,
    required DateTime now,
  }) {
    final results = <DateTime>[];
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final sleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final interval = prefs.intervalMinutes;
    final nowMin = now.hour * 60 + now.minute;

    int boundary = wakeMin + interval;
    while (boundary <= sleepMin) {
      if (boundary > nowMin) {
        results.add(DateTime(
          now.year, now.month, now.day,
          boundary ~/ 60, boundary % 60,
        ));
      }
      boundary += interval;
      if (results.length >= 24) break;
    }
    return results;
  }
}
