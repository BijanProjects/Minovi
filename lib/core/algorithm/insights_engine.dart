import 'dart:math';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/domain/model/insight_report.dart';

/// Pure-Dart analysis engine that crunches journal entries into structured
/// insights. No network, no LLM — deterministic pattern detection.
class InsightsEngine {
  const InsightsEngine._();

  /// Analyse [entries] within the given date range and produce an [InsightReport].
  static InsightReport analyse({
    required List<JournalEntry> entries,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final filled = entries.where((e) => e.hasContent).toList();

    // ── Basic aggregates ──
    final activeDays = <String>{};
    final timeByActivity = <String, int>{};
    final moodFrequency = <String, int>{};
    int totalMinutes = 0;

    // Per-day mood tracking for timeline
    final dayMoods = <String, Map<String, int>>{}; // dateKey → {mood → count}

    // Activity-mood matrix
    final activityMoods =
        <String, Map<String, int>>{}; // activity → {mood → count}
    final activityMinutes = <String, int>{};

    // Time-of-day buckets (hour → minutes tracked)
    final hourBuckets = <int, int>{};

    for (final entry in filled) {
      final dateKey = _dateKey(entry.date);
      activeDays.add(dateKey);

      final duration = _safeDuration(entry);
      totalMinutes += duration;

      // Activity time
      for (final tag in entry.tags) {
        timeByActivity[tag] = (timeByActivity[tag] ?? 0) + duration;
        activityMinutes[tag] = (activityMinutes[tag] ?? 0) + duration;
      }
      if (entry.tags.isEmpty) {
        timeByActivity['Untagged'] =
            (timeByActivity['Untagged'] ?? 0) + duration;
      }

      // Mood frequency
      for (final mood in entry.moods) {
        moodFrequency[mood] = (moodFrequency[mood] ?? 0) + 1;

        // Per-day mood
        dayMoods.putIfAbsent(dateKey, () => {});
        dayMoods[dateKey]![mood] = (dayMoods[dateKey]![mood] ?? 0) + 1;
      }

      // Activity-mood correlation
      for (final tag in entry.tags) {
        activityMoods.putIfAbsent(tag, () => {});
        for (final mood in entry.moods) {
          activityMoods[tag]![mood] = (activityMoods[tag]![mood] ?? 0) + 1;
        }
      }

      // Time-of-day tracking
      final startHour = _parseHour(entry.startTime);
      hourBuckets[startHour] = (hourBuckets[startHour] ?? 0) + duration;
    }

    // ── Mood timeline ──
    final moodTimeline = <MoodDayPoint>[];
    for (var d = rangeStart;
        !d.isAfter(rangeEnd);
        d = d.add(const Duration(days: 1))) {
      final key = _dateKey(d);
      final moods = dayMoods[key];
      if (moods != null && moods.isNotEmpty) {
        final dominant =
            moods.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        final count =
            filled.where((e) => _dateKey(e.date) == key).length;
        moodTimeline.add(MoodDayPoint(
          date: d,
          dominantMood: dominant,
          entryCount: count,
        ));
      }
    }

    // ── Correlations ──
    final correlations = <MoodActivityCorrelation>[];
    for (final entry in activityMoods.entries) {
      final dist = entry.value;
      String? dominant;
      int maxC = 0;
      dist.forEach((m, c) {
        if (c > maxC) {
          maxC = c;
          dominant = m;
        }
      });
      correlations.add(MoodActivityCorrelation(
        activity: entry.key,
        moodDistribution: dist,
        dominantMood: dominant,
        totalMinutes: activityMinutes[entry.key] ?? 0,
      ));
    }
    correlations.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    // ── Pattern detection ──
    final patterns = <InsightPattern>[];
    _detectTimeWaste(patterns, timeByActivity, totalMinutes);
    _detectMoodTrends(patterns, moodTimeline);
    _detectActivityMoodLinks(patterns, correlations);
    _detectConsistency(patterns, activeDays, rangeStart, rangeEnd);
    _detectPeakHours(patterns, hourBuckets);

    // ── Template narrative ──
    final narrative = _generateNarrative(
      filled: filled,
      activeDays: activeDays.length,
      totalMinutes: totalMinutes,
      timeByActivity: timeByActivity,
      moodFrequency: moodFrequency,
      patterns: patterns,
      correlations: correlations,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    return InsightReport(
      generatedAt: DateTime.now(),
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      totalEntries: filled.length,
      activeDays: activeDays.length,
      totalTrackedMinutes: totalMinutes,
      timeByActivity: timeByActivity,
      moodFrequency: moodFrequency,
      moodTimeline: moodTimeline,
      correlations: correlations,
      patterns: patterns,
      narrative: narrative,
      isLlmGenerated: false,
    );
  }

  // ─── Pattern detectors ──────────────────────────────────────────

  static void _detectTimeWaste(
    List<InsightPattern> out,
    Map<String, int> timeByActivity,
    int totalMinutes,
  ) {
    if (totalMinutes == 0) return;
    final sorted = timeByActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      final pct = entry.value / totalMinutes;
      if (pct >= 0.35) {
        out.add(InsightPattern(
          type: PatternType.timeWaste,
          title: '${entry.key} dominates your time',
          description:
              '${entry.key} takes up ${(pct * 100).toStringAsFixed(0)}% of your '
              'tracked time (${_formatMinutes(entry.value)}). Consider whether '
              'this aligns with your priorities.',
          confidence: min(1.0, pct),
        ));
      }
    }
  }

  static void _detectMoodTrends(
    List<InsightPattern> out,
    List<MoodDayPoint> timeline,
  ) {
    if (timeline.length < 3) return;

    // Detect streaks of the same mood
    String? streakMood;
    int streakLen = 0;
    int maxStreakLen = 0;
    String? maxStreakMood;

    for (final point in timeline) {
      if (point.dominantMood == streakMood) {
        streakLen++;
      } else {
        if (streakLen > maxStreakLen) {
          maxStreakLen = streakLen;
          maxStreakMood = streakMood;
        }
        streakMood = point.dominantMood;
        streakLen = 1;
      }
    }
    if (streakLen > maxStreakLen) {
      maxStreakLen = streakLen;
      maxStreakMood = streakMood;
    }

    if (maxStreakLen >= 3 && maxStreakMood != null) {
      final isNegative = _isNegativeMood(maxStreakMood);
      out.add(InsightPattern(
        type: PatternType.moodTrend,
        title: isNegative
            ? 'Prolonged $maxStreakMood streak detected'
            : '$maxStreakMood streak for $maxStreakLen days',
        description: isNegative
            ? 'You felt $maxStreakMood for $maxStreakLen consecutive days. '
                'This sustained negative mood may need attention — consider '
                'what changed around that period.'
            : 'Great news! You maintained a $maxStreakMood mood for '
                '$maxStreakLen consecutive days. Look at what activities '
                'you were doing to replicate this.',
        confidence: min(1.0, maxStreakLen / 7),
      ));
    }

    // Detect mood shift (first half vs second half)
    final mid = timeline.length ~/ 2;
    final firstHalf = timeline.sublist(0, mid);
    final secondHalf = timeline.sublist(mid);

    final firstNeg = firstHalf.where((p) => _isNegativeMood(p.dominantMood)).length;
    final secondNeg = secondHalf.where((p) => _isNegativeMood(p.dominantMood)).length;
    final firstPos = firstHalf.length - firstNeg;
    final secondPos = secondHalf.length - secondNeg;

    if (firstNeg > firstPos && secondPos > secondNeg) {
      out.add(InsightPattern(
        type: PatternType.moodTrend,
        title: 'Mood is improving',
        description: 'Your mood shifted from predominantly negative in the '
            'first half to more positive recently. Keep doing what you are doing!',
        confidence: 0.7,
      ));
    } else if (firstPos > firstNeg && secondNeg > secondPos) {
      out.add(InsightPattern(
        type: PatternType.moodTrend,
        title: 'Mood is declining',
        description: 'Your mood has trended downward recently compared to '
            'the earlier period. Review recent changes in your routine that '
            'might be contributing.',
        confidence: 0.7,
      ));
    }
  }

  static void _detectActivityMoodLinks(
    List<InsightPattern> out,
    List<MoodActivityCorrelation> correlations,
  ) {
    for (final corr in correlations) {
      if (corr.moodDistribution.isEmpty) continue;
      final total =
          corr.moodDistribution.values.fold<int>(0, (s, v) => s + v);
      if (total < 3) continue; // need enough data points

      for (final moodEntry in corr.moodDistribution.entries) {
        final ratio = moodEntry.value / total;
        if (ratio >= 0.6) {
          final isNeg = _isNegativeMood(moodEntry.key);
          out.add(InsightPattern(
            type: PatternType.activityMoodLink,
            title: '${corr.activity} → ${moodEntry.key}',
            description: isNeg
                ? '${(ratio * 100).toStringAsFixed(0)}% of the time you do '
                    '${corr.activity}, you feel ${moodEntry.key}. '
                    'This activity may be negatively impacting your wellbeing.'
                : '${(ratio * 100).toStringAsFixed(0)}% of the time you do '
                    '${corr.activity}, you feel ${moodEntry.key}. '
                    'This activity is a strong positive contributor to your mood.',
            confidence: ratio,
          ));
        }
      }
    }
  }

  static void _detectConsistency(
    List<InsightPattern> out,
    Set<String> activeDays,
    DateTime start,
    DateTime end,
  ) {
    final totalDays = end.difference(start).inDays + 1;
    if (totalDays == 0) return;
    final rate = activeDays.length / totalDays;

    if (rate < 0.4) {
      out.add(InsightPattern(
        type: PatternType.consistency,
        title: 'Low tracking consistency',
        description:
            'You only tracked ${activeDays.length} out of $totalDays days '
            '(${(rate * 100).toStringAsFixed(0)}%). More consistent tracking '
            'will help reveal clearer patterns in your habits and moods.',
        confidence: 1 - rate,
      ));
    } else if (rate >= 0.85) {
      out.add(InsightPattern(
        type: PatternType.consistency,
        title: 'Excellent tracking habit',
        description:
            'You tracked ${activeDays.length} out of $totalDays days '
            '(${(rate * 100).toStringAsFixed(0)}%). This consistency '
            'makes your insights highly reliable.',
        confidence: rate,
      ));
    }
  }

  static void _detectPeakHours(
    List<InsightPattern> out,
    Map<int, int> hourBuckets,
  ) {
    if (hourBuckets.isEmpty) return;
    final sorted = hourBuckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final peak = sorted.first;
    final peakLabel = _formatHour(peak.key);
    out.add(InsightPattern(
      type: PatternType.peakProductivity,
      title: 'Most active around $peakLabel',
      description:
          'You log the most activity starting at $peakLabel '
          '(${_formatMinutes(peak.value)} total). Schedule important tasks '
          'around this time for best results.',
      confidence: 0.6,
    ));
  }

  // ─── Narrative generator ────────────────────────────────────────

  static String _generateNarrative({
    required List<JournalEntry> filled,
    required int activeDays,
    required int totalMinutes,
    required Map<String, int> timeByActivity,
    required Map<String, int> moodFrequency,
    required List<InsightPattern> patterns,
    required List<MoodActivityCorrelation> correlations,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final buf = StringBuffer();
    final days = rangeEnd.difference(rangeStart).inDays + 1;

    // ── Overview
    buf.writeln('## Your ${days}-Day Overview\n');
    buf.writeln(
        'Over the past $days days, you tracked **${filled.length} entries** '
        'across **$activeDays active days**, totalling '
        '**${_formatMinutes(totalMinutes)}** of logged time.\n');

    // ── Time distribution
    if (timeByActivity.isNotEmpty) {
      buf.writeln('### How You Spent Your Time\n');
      final sorted = timeByActivity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        final pct = totalMinutes > 0
            ? (e.value / totalMinutes * 100).toStringAsFixed(1)
            : '0';
        buf.writeln('- **${e.key}**: ${_formatMinutes(e.value)} ($pct%)');
      }
      buf.writeln();
    }

    // ── Mood overview
    if (moodFrequency.isNotEmpty) {
      buf.writeln('### Mood Snapshot\n');
      final sorted = moodFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topMood = sorted.first.key;
      buf.writeln(
          'Your most frequent mood was **$topMood** '
          '(${sorted.first.value} times). ');
      if (sorted.length > 1) {
        buf.writeln(
            'Followed by **${sorted[1].key}** (${sorted[1].value} times).');
      }
      buf.writeln();
    }

    // ── Key patterns
    if (patterns.isNotEmpty) {
      buf.writeln('### Key Patterns Detected\n');
      for (final p in patterns) {
        buf.writeln('**${p.title}**');
        buf.writeln('${p.description}\n');
      }
    }

    // ── Activity-mood links
    final significant = correlations
        .where((c) => c.moodDistribution.isNotEmpty && c.totalMinutes >= 30)
        .take(3)
        .toList();
    if (significant.isNotEmpty) {
      buf.writeln('### Activity & Mood Connections\n');
      for (final c in significant) {
        buf.writeln(
            '- **${c.activity}** (${_formatMinutes(c.totalMinutes)}): '
            'mostly felt **${c.dominantMood ?? 'mixed'}**');
      }
      buf.writeln();
    }

    // ── Suggestions
    final negativeMoods =
        moodFrequency.entries.where((e) => _isNegativeMood(e.key)).toList();
    if (negativeMoods.isNotEmpty) {
      buf.writeln('### Suggestions\n');
      for (final nm in negativeMoods.take(2)) {
        final linkedActivities = correlations
            .where((c) => c.dominantMood == nm.key)
            .map((c) => c.activity)
            .toList();
        if (linkedActivities.isNotEmpty) {
          buf.writeln(
              '- When you feel **${nm.key}**, it\'s often linked to '
              '**${linkedActivities.join(', ')}**. Consider adjusting the '
              'time or approach to these activities.');
        }
      }
      buf.writeln();
    }

    return buf.toString();
  }

  // ─── Helpers ────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int _safeDuration(JournalEntry e) {
    try {
      final d = e.durationMinutes;
      return d > 0 ? d : 0;
    } catch (_) {
      return 0;
    }
  }

  static int _parseHour(String time) {
    final parts = time.split(':');
    return int.tryParse(parts[0]) ?? 0;
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String _formatHour(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final amPm = hour < 12 ? 'AM' : 'PM';
    return '$h12 $amPm';
  }

  static bool _isNegativeMood(String mood) {
    const negative = {
      'Sad', 'Angry', 'Anxious', 'Ashamed', 'Tired', 'Stressed',
    };
    return negative.contains(mood);
  }
}
