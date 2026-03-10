import 'package:chronosense/domain/model/insight_report.dart';
import 'package:chronosense/domain/model/models.dart';

/// Builds a structured prompt from analysis data that can be fed to an
/// on-device LLM for natural-language report generation.
class PromptBuilder {
  const PromptBuilder._();

  /// Build a prompt for the on-device LLM from the structured report.
  static String buildInsightPrompt({
    required InsightReport report,
    required List<JournalEntry> entries,
  }) {
    final buf = StringBuffer();

    buf.writeln('You are Minovi, a personal wellbeing assistant that runs '
        'entirely on the user\'s device. Your job is to analyse their time '
        'tracking and mood data, then provide a warm, insightful, and '
        'actionable report. Be empathetic but honest. Use clear paragraphs '
        'with markdown headings.\n');

    buf.writeln('## DATA SUMMARY');
    buf.writeln('Period: ${_fmtDate(report.rangeStart)} to ${_fmtDate(report.rangeEnd)}');
    buf.writeln('Active days: ${report.activeDays}');
    buf.writeln('Total entries: ${report.totalEntries}');
    buf.writeln('Total tracked time: ${_fmtMin(report.totalTrackedMinutes)}\n');

    // Time distribution
    buf.writeln('## TIME BY ACTIVITY');
    final sortedAct = report.timeByActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedAct) {
      final pct = report.totalTrackedMinutes > 0
          ? (e.value / report.totalTrackedMinutes * 100).toStringAsFixed(1)
          : '0';
      buf.writeln('- ${e.key}: ${_fmtMin(e.value)} ($pct%)');
    }
    buf.writeln();

    // Mood frequency
    buf.writeln('## MOOD FREQUENCY');
    final sortedMood = report.moodFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedMood) {
      buf.writeln('- ${e.key}: ${e.value} times');
    }
    buf.writeln();

    // Mood timeline
    if (report.moodTimeline.isNotEmpty) {
      buf.writeln('## MOOD TIMELINE (day → dominant mood)');
      for (final p in report.moodTimeline) {
        buf.writeln('- ${_fmtDate(p.date)}: ${p.dominantMood} (${p.entryCount} entries)');
      }
      buf.writeln();
    }

    // Activity-mood correlations
    if (report.correlations.isNotEmpty) {
      buf.writeln('## ACTIVITY-MOOD CORRELATIONS');
      for (final c in report.correlations.take(5)) {
        buf.writeln('- ${c.activity} (${_fmtMin(c.totalMinutes)}): '
            'dominant mood = ${c.dominantMood ?? "mixed"}, '
            'distribution = ${c.moodDistribution}');
      }
      buf.writeln();
    }

    // Detected patterns
    if (report.patterns.isNotEmpty) {
      buf.writeln('## DETECTED PATTERNS');
      for (final p in report.patterns) {
        buf.writeln('- [${p.type.name}] ${p.title}: ${p.description}');
      }
      buf.writeln();
    }

    // Sample entries for context
    buf.writeln('## SAMPLE ENTRIES (recent)');
    final recentEntries = entries
        .where((e) => e.hasContent)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final e in recentEntries.take(10)) {
      buf.writeln('- ${_fmtDate(e.date)} ${e.startTime}-${e.endTime}: '
          '${e.description.isNotEmpty ? e.description : "(no description)"} '
          '[moods: ${e.moods.join(", ")}] [tags: ${e.tags.join(", ")}]');
    }
    buf.writeln();

    buf.writeln('## INSTRUCTIONS');
    buf.writeln('Based on the above data, write a personalised wellbeing report:');
    buf.writeln('1. Summarise how the user spent their time');
    buf.writeln('2. Identify patterns in their mood over the period');
    buf.writeln('3. Highlight activities that correlate with negative moods');
    buf.writeln('4. Highlight activities that correlate with positive moods');
    buf.writeln('5. Point out any time sinks or imbalances');
    buf.writeln('6. Provide 2-3 specific, actionable suggestions');
    buf.writeln('7. End with an encouraging note');
    buf.writeln('\nKeep the tone warm and supportive. Use markdown formatting.');

    return buf.toString();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtMin(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
