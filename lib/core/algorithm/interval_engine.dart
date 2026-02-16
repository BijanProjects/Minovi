import 'package:chronosense/domain/model/models.dart';

/// Stateless, O(S + E·logE) interval engine.
/// Generates time slots, finds active slot index, computes next notification time.
class IntervalEngine {
  const IntervalEngine._();

  /// Generate time slots for a day based on preferences,
  /// then overlay any matching journal entries.
  ///
  /// Recorded entries (those with content) are treated as immovable anchors
  /// whose original time boundaries are always preserved.  All remaining
  /// unrecorded time is divided into slots using the current interval setting.
  /// This means changing the interval only affects empty/future slots and never
  /// overwrites previously recorded data.
  static List<TimeSlot> generateSlots({
    required UserPreferences prefs,
    required List<JournalEntry> entries,
  }) {
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final sleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final interval = prefs.intervalMinutes;

    // Collect recorded (has content) entries as anchored blocks, sorted.
    final anchorBlocks = <({int startMin, int endMin, JournalEntry entry})>[];
    for (final entry in entries) {
      if (entry.hasContent) {
        final sp = entry.startTime.split(':');
        final ep = entry.endTime.split(':');
        anchorBlocks.add((
          startMin: int.parse(sp[0]) * 60 + int.parse(sp[1]),
          endMin: int.parse(ep[0]) * 60 + int.parse(ep[1]),
          entry: entry,
        ));
      }
    }
    anchorBlocks.sort((a, b) => a.startMin.compareTo(b.startMin));

    final slots = <TimeSlot>[];
    int current = wakeMin;
    int blockIdx = 0;

    while (current < sleepMin) {
      // Skip anchors whose start we've already passed.
      while (blockIdx < anchorBlocks.length &&
          anchorBlocks[blockIdx].startMin < current) {
        blockIdx++;
      }

      // If an anchor starts exactly here, emit it and jump past it.
      if (blockIdx < anchorBlocks.length &&
          anchorBlocks[blockIdx].startMin == current) {
        final block = anchorBlocks[blockIdx];
        slots.add(TimeSlot(
          startTime: block.entry.startTime,
          endTime: block.entry.endTime,
          entry: block.entry,
        ));
        current = block.endMin;
        blockIdx++;
        continue;
      }

      // No anchor here — generate an unrecorded slot with current interval.
      int slotEnd = current + interval;

      // Don't exceed sleep time.
      if (slotEnd > sleepMin) break;

      // Don't overlap into the next anchor.
      if (blockIdx < anchorBlocks.length &&
          slotEnd > anchorBlocks[blockIdx].startMin) {
        slotEnd = anchorBlocks[blockIdx].startMin;
      }

      if (slotEnd <= current) break; // safety

      slots.add(TimeSlot(
        startTime: _minutesToTimeStr(current),
        endTime: _minutesToTimeStr(slotEnd),
        entry: null,
      ));
      current = slotEnd;
    }

    return slots;
  }

  // ── helpers ──

  static String _minutesToTimeStr(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
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
