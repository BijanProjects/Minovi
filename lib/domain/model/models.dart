// All domain models for ChronoSense.

// ─── Mood ───────────────────────────────────────────────────────────
enum Mood {
  energetic(emoji: '🔥', label: 'Energetic', colorHex: 0xFFF59E0B, sortOrder: 0),
  happy(emoji: '😊', label: 'Happy', colorHex: 0xFF10B981, sortOrder: 1),
  focused(emoji: '🎯', label: 'Focused', colorHex: 0xFF6366F1, sortOrder: 2),
  calm(emoji: '😌', label: 'Calm', colorHex: 0xFF14B8A6, sortOrder: 3),
  neutral(emoji: '😐', label: 'Neutral', colorHex: 0xFF8B5CF6, sortOrder: 4),
  tired(emoji: '😴', label: 'Tired', colorHex: 0xFF94A3B8, sortOrder: 5),
  stressed(emoji: '😰', label: 'Stressed', colorHex: 0xFFF43F5E, sortOrder: 6);

  final String emoji;
  final String label;
  final int colorHex;
  final int sortOrder;

  const Mood({
    required this.emoji,
    required this.label,
    required this.colorHex,
    required this.sortOrder,
  });

  static Mood? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      return Mood.values.firstWhere(
        (m) => m.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ─── ActivityTag ────────────────────────────────────────────────────
enum ActivityTag {
  work(label: 'Work', icon: '💼', colorHex: 0xFF3B82F6),
  exercise(label: 'Exercise', icon: '🏃', colorHex: 0xFF10B981),
  social(label: 'Social', icon: '👥', colorHex: 0xFFF59E0B),
  creative(label: 'Creative', icon: '🎨', colorHex: 0xFFA855F7),
  rest(label: 'Rest', icon: '🛋️', colorHex: 0xFF64748B),
  learning(label: 'Learning', icon: '📚', colorHex: 0xFF6366F1),
  commute(label: 'Commute', icon: '🚗', colorHex: 0xFF78716C),
  meals(label: 'Meals', icon: '🍽️', colorHex: 0xFFEF4444),
  entertainment(label: 'Entertainment', icon: '🎮', colorHex: 0xFFEC4899),
  selfCare(label: 'Self-care', icon: '🧘', colorHex: 0xFF14B8A6);

  final String label;
  final String icon;
  final int colorHex;

  const ActivityTag({
    required this.label,
    required this.icon,
    required this.colorHex,
  });

  static ActivityTag? fromLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    try {
      return ActivityTag.values.firstWhere(
        (t) => t.label.toLowerCase() == label.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ─── JournalEntry ───────────────────────────────────────────────────
class JournalEntry {
  final int? id;
  final DateTime date;
  final String startTime; // "HH:mm"
  final String endTime;   // "HH:mm"
  final String description;
  final Mood? mood;
  final List<ActivityTag> tags;
  final int createdAt; // millis

  const JournalEntry({
    this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.description = '',
    this.mood,
    this.tags = const [],
    required this.createdAt,
  });

  bool get hasContent =>
      description.isNotEmpty || mood != null || tags.isNotEmpty;

  int get durationMinutes {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMin - startMin;
  }

  JournalEntry copyWith({
    int? id,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? description,
    Mood? mood,
    bool clearMood = false,
    List<ActivityTag>? tags,
    int? createdAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      mood: clearMood ? null : (mood ?? this.mood),
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ─── TimeSlot ───────────────────────────────────────────────────────
class TimeSlot {
  final String startTime; // "HH:mm"
  final String endTime;   // "HH:mm"
  final JournalEntry? entry;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    this.entry,
  });

  bool get isFilled => entry != null && entry!.hasContent;

  int get durationMinutes {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMin - startMin;
  }
}

// ─── DaySummary ─────────────────────────────────────────────────────
class DaySummary {
  final int totalSlots;
  final int filledSlots;
  final Mood? dominantMood;
  final List<ActivityTag> topTags;
  final double completionRate;

  const DaySummary({
    required this.totalSlots,
    required this.filledSlots,
    this.dominantMood,
    this.topTags = const [],
    required this.completionRate,
  });

  factory DaySummary.fromSlots(List<TimeSlot> slots) {
    final filled = slots.where((s) => s.isFilled).toList();
    final total = slots.length;
    final rate = total > 0 ? filled.length / total : 0.0;

    // Dominant mood
    final moodCounts = <Mood, int>{};
    for (final slot in filled) {
      if (slot.entry?.mood != null) {
        moodCounts[slot.entry!.mood!] =
            (moodCounts[slot.entry!.mood!] ?? 0) + 1;
      }
    }
    Mood? dominant;
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        dominant = mood;
      }
    });

    // Top tags
    final tagCounts = <ActivityTag, int>{};
    for (final slot in filled) {
      for (final tag in slot.entry?.tags ?? <ActivityTag>[]) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = sortedTags.take(3).map((e) => e.key).toList();

    return DaySummary(
      totalSlots: total,
      filledSlots: filled.length,
      dominantMood: dominant,
      topTags: topTags,
      completionRate: rate,
    );
  }
}

// ─── MonthInsight ───────────────────────────────────────────────────
class MonthInsight {
  final int totalEntries;
  final int activeDays;
  final Map<ActivityTag, int> tagFrequency;
  final Map<Mood, int> moodFrequency;
  final Set<int> daysWithEntries;
  final double averageCompletionRate;

  const MonthInsight({
    required this.totalEntries,
    required this.activeDays,
    required this.tagFrequency,
    required this.moodFrequency,
    required this.daysWithEntries,
    required this.averageCompletionRate,
  });

  ActivityTag? get topActivity {
    if (tagFrequency.isEmpty) return null;
    return tagFrequency.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  Mood? get dominantMood {
    if (moodFrequency.isEmpty) return null;
    return moodFrequency.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  factory MonthInsight.aggregate({
    required List<JournalEntry> entries,
    required int totalSlotsPerDay,
  }) {
    if (entries.isEmpty) {
      return const MonthInsight(
        totalEntries: 0,
        activeDays: 0,
        tagFrequency: {},
        moodFrequency: {},
        daysWithEntries: {},
        averageCompletionRate: 0,
      );
    }

    final dayEntries = <int, int>{};
    final tagFreq = <ActivityTag, int>{};
    final moodFreq = <Mood, int>{};
    final days = <int>{};

    for (final entry in entries) {
      if (!entry.hasContent) continue;
      final day = entry.date.day;
      days.add(day);
      dayEntries[day] = (dayEntries[day] ?? 0) + 1;

      if (entry.mood != null) {
        moodFreq[entry.mood!] = (moodFreq[entry.mood!] ?? 0) + 1;
      }
      for (final tag in entry.tags) {
        tagFreq[tag] = (tagFreq[tag] ?? 0) + 1;
      }
    }

    double avgCompletion = 0;
    if (dayEntries.isNotEmpty && totalSlotsPerDay > 0) {
      final totalRates = dayEntries.values
          .map((count) => count / totalSlotsPerDay)
          .reduce((a, b) => a + b);
      avgCompletion = totalRates / dayEntries.length;
    }

    return MonthInsight(
      totalEntries: entries.where((e) => e.hasContent).length,
      activeDays: days.length,
      tagFrequency: tagFreq,
      moodFrequency: moodFreq,
      daysWithEntries: days,
      averageCompletionRate: avgCompletion.clamp(0.0, 1.0),
    );
  }
}

// ─── UserPreferences ────────────────────────────────────────────────
class UserPreferences {
  final int wakeHour;
  final int wakeMinute;
  final int sleepHour;
  final int sleepMinute;
  final int intervalMinutes;
  final bool notificationsEnabled;
  final bool dynamicColors;

  static const List<int> intervalOptions = [30, 60, 90, 120, 180, 240];

  const UserPreferences({
    this.wakeHour = 7,
    this.wakeMinute = 0,
    this.sleepHour = 23,
    this.sleepMinute = 0,
    this.intervalMinutes = 120,
    this.notificationsEnabled = true,
    this.dynamicColors = false,
  });

  String get wakeTimeFormatted =>
      '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}';
  String get sleepTimeFormatted =>
      '${sleepHour.toString().padLeft(2, '0')}:${sleepMinute.toString().padLeft(2, '0')}';

  int get wakingMinutes {
    final wakeMin = wakeHour * 60 + wakeMinute;
    final sleepMin = sleepHour * 60 + sleepMinute;
    return sleepMin > wakeMin ? sleepMin - wakeMin : (1440 - wakeMin) + sleepMin;
  }

  int get totalSlots => (wakingMinutes / intervalMinutes).floor();

  UserPreferences copyWith({
    int? wakeHour,
    int? wakeMinute,
    int? sleepHour,
    int? sleepMinute,
    int? intervalMinutes,
    bool? notificationsEnabled,
    bool? dynamicColors,
  }) {
    return UserPreferences(
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      sleepHour: sleepHour ?? this.sleepHour,
      sleepMinute: sleepMinute ?? this.sleepMinute,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dynamicColors: dynamicColors ?? this.dynamicColors,
    );
  }
}
