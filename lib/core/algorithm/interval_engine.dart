import 'package:chronosense/domain/model/models.dart';

/// Stateless, O(S + E·logE) interval engine.
/// Generates time slots, finds active slot index, computes next notification time.
class IntervalEngine {
  const IntervalEngine._();

  static List<TimeSlot> generateSlots({
    required UserPreferences prefs,
    required List<JournalEntry> entries,
  }) {
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final rawSleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final sleepBoundary = _normalizeSleepBoundary(
      wakeMin: wakeMin,
      sleepMin: rawSleepMin,
    );
    final interval = prefs.intervalMinutes;

    final anchorBlocks = <({int startMin, int endMin, JournalEntry entry})>[];
    for (final entry in entries) {
      if (entry.hasContent) {
        final sp = entry.startTime.split(':');
        final ep = entry.endTime.split(':');
        var startMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
        var endMin = int.parse(ep[0]) * 60 + int.parse(ep[1]);
        if (startMin < wakeMin) {
          startMin += 1440;
        }
        if (endMin <= startMin) {
          endMin += 1440;
        }
        anchorBlocks.add((
          startMin: startMin,
          endMin: endMin,
          entry: entry,
        ));
      }
    }
    anchorBlocks.sort((a, b) => a.startMin.compareTo(b.startMin));

    final slots = <TimeSlot>[];
    int current = wakeMin;
    int blockIdx = 0;

    while (current < sleepBoundary) {
      while (blockIdx < anchorBlocks.length &&
          anchorBlocks[blockIdx].startMin < current) {
        blockIdx++;
      }

      if (blockIdx < anchorBlocks.length &&
          anchorBlocks[blockIdx].startMin == current) {
        final block = anchorBlocks[blockIdx];
        slots.add(TimeSlot(
          startTime: _minutesToTimeStr(block.startMin),
          endTime: _minutesToTimeStr(block.endMin),
          entry: block.entry,
        ));
        current = block.endMin;
        blockIdx++;
        continue;
      }

      int slotEnd = current + interval;
      if (slotEnd > sleepBoundary) break;

      if (blockIdx < anchorBlocks.length &&
          slotEnd > anchorBlocks[blockIdx].startMin) {
        slotEnd = anchorBlocks[blockIdx].startMin;
      }

      if (slotEnd <= current) break;

      slots.add(TimeSlot(
        startTime: _minutesToTimeStr(current),
        endTime: _minutesToTimeStr(slotEnd),
        entry: null,
      ));
      current = slotEnd;
    }

    return slots;
  }

  static String _minutesToTimeStr(int minutes) {
    final mDay = ((minutes % 1440) + 1440) % 1440;
    final h = mDay ~/ 60;
    final m = mDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int findActiveSlotIndex(List<TimeSlot> slots, DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    for (int i = 0; i < slots.length; i++) {
      final parts = slots[i].startTime.split(':');
      var startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final eParts = slots[i].endTime.split(':');
      var endMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);

      if (endMin <= startMin) {
        endMin += 1440;
      }

      var normalizedNow = nowMin;
      if (normalizedNow < startMin) {
        normalizedNow += 1440;
      }

      if (normalizedNow >= startMin && normalizedNow < endMin) {
        return i;
      }
    }
    return -1;
  }

  static DateTime? nextNotificationTime({
    required UserPreferences prefs,
    required DateTime now,
  }) {
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final rawSleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final sleepBoundary = _normalizeSleepBoundary(
      wakeMin: wakeMin,
      sleepMin: rawSleepMin,
    );
    final interval = prefs.intervalMinutes;
    final nowMin = now.hour * 60 + now.minute;

    int boundary = wakeMin + interval;
    while (boundary <= sleepBoundary) {
      final boundaryClockMin = boundary % 1440;
      final boundaryToday = DateTime(
        now.year,
        now.month,
        now.day,
        boundaryClockMin ~/ 60,
        boundaryClockMin % 60,
      );
      final candidate = boundaryToday.isAfter(now)
          ? boundaryToday
          : boundaryToday.add(const Duration(days: 1));
      if (candidate.isAfter(now)) {
        return candidate;
      }
      boundary += interval;
    }
    return null;
  }

  static List<DateTime> remainingBoundaries({
    required UserPreferences prefs,
    required DateTime now,
  }) {
    final results = <DateTime>[];
    final wakeMin = prefs.wakeHour * 60 + prefs.wakeMinute;
    final rawSleepMin = prefs.sleepHour * 60 + prefs.sleepMinute;
    final sleepBoundary = _normalizeSleepBoundary(
      wakeMin: wakeMin,
      sleepMin: rawSleepMin,
    );
    final interval = prefs.intervalMinutes;

    int boundary = wakeMin + interval;
    while (boundary <= sleepBoundary) {
      final boundaryClockMin = boundary % 1440;
      final boundaryToday = DateTime(
        now.year,
        now.month,
        now.day,
        boundaryClockMin ~/ 60,
        boundaryClockMin % 60,
      );
      final candidate = boundaryToday.isAfter(now)
          ? boundaryToday
          : boundaryToday.add(const Duration(days: 1));
      if (candidate.isAfter(now)) {
        results.add(candidate);
      }
      boundary += interval;
      if (results.length >= 24) break;
    }
    return results;
  }

  static int _normalizeSleepBoundary({
    required int wakeMin,
    required int sleepMin,
  }) {
    if (sleepMin <= wakeMin) {
      return sleepMin + 1440;
    }
    return sleepMin;
  }
}
