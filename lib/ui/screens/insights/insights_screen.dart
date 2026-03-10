import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/domain/model/insight_report.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/domain/service/on_device_ai_service.dart';
import 'package:chronosense/ui/screens/insights/insights_provider.dart';
import 'package:chronosense/ui/design/tokens.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Auto-generate report on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(insightsProvider);
      if (state.report == null && !state.isLoading) {
        ref.read(insightsProvider.notifier).generateReport();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Trigger fade-in when report arrives
    if (state.report != null && !_fadeController.isCompleted) {
      _fadeController.forward();
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.lg),
          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Text(
              'Insights',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // ── Date range chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: _DateRangeSelector(
              current: state.dateRange,
              onSelected: (range) {
                ref.read(insightsProvider.notifier).setDateRange(range);
              },
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // ── Content ──
          Expanded(
            child: state.isLoading
                ? _buildLoading(cs)
                : state.error != null
                    ? _buildError(state.error!, cs, theme)
                    : state.report != null
                        ? FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildReport(state.report!, state, theme, cs),
                          )
                        : _buildEmpty(cs, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Analysing your data...',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Everything stays on your device',
            style: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, ColorScheme cs, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 64, color: cs.outline),
            const SizedBox(height: Spacing.lg),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(insightsProvider.notifier).generateReport(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_outlined, size: 64, color: cs.outline),
          const SizedBox(height: Spacing.lg),
          Text(
            'Tap below to generate your insight report',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          FilledButton.icon(
            onPressed: () =>
                ref.read(insightsProvider.notifier).generateReport(),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(
    InsightReport report,
    InsightsState state,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      children: [
        // ── AI badge ──
        _AiBadge(
          isLlmGenerated: report.isLlmGenerated,
          aiStatus: state.aiStatus,
          downloadProgress: state.downloadProgress,
          onPrepare: () =>
              ref.read(insightsProvider.notifier).prepareModel(),
          onCancel: () =>
              ref.read(insightsProvider.notifier).cancelDownload(),
        ),
        const SizedBox(height: Spacing.lg),

        // ── Overview card ──
        _OverviewCard(report: report),
        const SizedBox(height: Spacing.md),

        // ── Time distribution ──
        if (report.timeByActivity.isNotEmpty) ...[
          const _SectionHeader(title: 'Time Distribution', icon: Icons.pie_chart_outline),
          const SizedBox(height: Spacing.sm),
          _TimeDistributionCard(report: report),
          const SizedBox(height: Spacing.md),
        ],

        // ── Mood overview ──
        if (report.moodFrequency.isNotEmpty) ...[
          const _SectionHeader(title: 'Mood Overview', icon: Icons.mood),
          const SizedBox(height: Spacing.sm),
          _MoodOverviewCard(report: report),
          const SizedBox(height: Spacing.md),
        ],

        // ── Mood timeline ──
        if (report.moodTimeline.length >= 2) ...[
          const _SectionHeader(title: 'Mood Timeline', icon: Icons.timeline),
          const SizedBox(height: Spacing.sm),
          _MoodTimelineCard(timeline: report.moodTimeline),
          const SizedBox(height: Spacing.md),
        ],

        // ── Patterns ──
        if (report.patterns.isNotEmpty) ...[
          const _SectionHeader(title: 'Patterns Detected', icon: Icons.pattern),
          const SizedBox(height: Spacing.sm),
          ...report.patterns.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _PatternCard(pattern: p),
              )),
          const SizedBox(height: Spacing.md),
        ],

        // ── Activity-mood connections ──
        if (report.correlations.isNotEmpty) ...[
          const _SectionHeader(
              title: 'Activity & Mood Links',
              icon: Icons.link),
          const SizedBox(height: Spacing.sm),
          ...report.correlations.take(5).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _CorrelationCard(correlation: c),
              )),
          const SizedBox(height: Spacing.md),
        ],

        // ── Narrative ──
        const _SectionHeader(title: 'Full Report', icon: Icons.article_outlined),
        const SizedBox(height: Spacing.sm),
        _NarrativeCard(narrative: report.narrative),
        const SizedBox(height: Spacing.xxl),

        // ── Regenerate button ──
        Center(
          child: TextButton.icon(
            onPressed: () =>
                ref.read(insightsProvider.notifier).generateReport(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Regenerate'),
          ),
        ),
        const SizedBox(height: Spacing.huge),
      ],
    );
  }
}

// ─── Date Range Selector ──────────────────────────────────────────

class _DateRangeSelector extends StatelessWidget {
  final DateRange current;
  final void Function(DateRange) onSelected;

  const _DateRangeSelector({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ranges = [
      DateRange.lastWeek(),
      DateRange.twoWeeksRange(),
      DateRange.lastMonth(),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((r) {
          final isSelected = r.label == current.label;
          return Padding(
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: FilterChip(
              label: Text(r.label),
              selected: isSelected,
              onSelected: (_) => onSelected(r),
              selectedColor: cs.primaryContainer,
              checkmarkColor: cs.onPrimaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── AI Badge ─────────────────────────────────────────────────────

class _AiBadge extends StatelessWidget {
  final bool isLlmGenerated;
  final AiModelStatus aiStatus;
  final double? downloadProgress;
  final VoidCallback onPrepare;
  final VoidCallback onCancel;

  const _AiBadge({
    required this.isLlmGenerated,
    required this.aiStatus,
    required this.onPrepare,
    required this.onCancel,
    this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: isLlmGenerated
          ? cs.primaryContainer.withValues(alpha: 0.5)
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Icon(
              isLlmGenerated ? Icons.auto_awesome : Icons.shield_outlined,
              size: 20,
              color: isLlmGenerated ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLlmGenerated
                        ? 'Enhanced by on-device AI'
                        : 'On-device analysis',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isLlmGenerated
                          ? cs.onPrimaryContainer
                          : cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Your data never leaves this device',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLlmGenerated &&
                aiStatus == AiModelStatus.notDownloaded) ...[
              TextButton(
                onPressed: onPrepare,
                child: const Text('Enable AI'),
              ),
            ],
            if (aiStatus == AiModelStatus.downloading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    downloadProgress != null
                        ? '${(downloadProgress! * 100).toStringAsFixed(0)}%'
                        : 'Downloading…',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: Spacing.sm),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Overview Card ────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final InsightReport report;

  const _OverviewCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final days = report.rangeEnd.difference(report.rangeStart).inDays + 1;

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$days-Day Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                _StatPill(
                  label: 'Entries',
                  value: '${report.totalEntries}',
                  cs: cs,
                ),
                const SizedBox(width: Spacing.sm),
                _StatPill(
                  label: 'Active Days',
                  value: '${report.activeDays}',
                  cs: cs,
                ),
                const SizedBox(width: Spacing.sm),
                _StatPill(
                  label: 'Time Logged',
                  value: _fmtMin(report.totalTrackedMinutes),
                  cs: cs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _StatPill({
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.sm,
          horizontal: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Time Distribution Card ───────────────────────────────────────

class _TimeDistributionCard extends StatelessWidget {
  final InsightReport report;

  const _TimeDistributionCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sorted = report.timeByActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = report.totalTrackedMinutes;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: sorted.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            final colorHex = activityColorHexForLabel(e.key);
            final icon = activityIconForLabel(e.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          e.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${_fmtMin(e.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: cs.outline.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(Color(colorHex)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Mood Overview Card ───────────────────────────────────────────

class _MoodOverviewCard extends StatelessWidget {
  final InsightReport report;

  const _MoodOverviewCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sorted = report.moodFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: sorted.map((e) {
            final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
            final emoji = moodEmojiForLabel(e.key);
            final colorHex = moodColorHexForLabel(e.key);

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Color(colorHex).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: Color(colorHex).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    '${e.key} $pct%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Color(colorHex),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Mood Timeline Card ───────────────────────────────────────────

class _MoodTimelineCard extends StatelessWidget {
  final List<MoodDayPoint> timeline;

  const _MoodTimelineCard({required this.timeline});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: timeline.map((point) {
              final emoji = moodEmojiForLabel(point.dominantMood);
              final colorHex = moodColorHexForLabel(point.dominantMood);
              final day = '${point.date.day}';

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: Spacing.xs),
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Color(colorHex),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      day,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Pattern Card ─────────────────────────────────────────────────

class _PatternCard extends StatelessWidget {
  final InsightPattern pattern;

  const _PatternCard({required this.pattern});

  IconData get _icon => switch (pattern.type) {
        PatternType.timeWaste => Icons.hourglass_bottom,
        PatternType.moodTrend => Icons.trending_up,
        PatternType.activityMoodLink => Icons.link,
        PatternType.consistency => Icons.calendar_today,
        PatternType.peakProductivity => Icons.flash_on,
        PatternType.suggestion => Icons.lightbulb_outline,
      };

  Color _color(ColorScheme cs) => switch (pattern.type) {
        PatternType.timeWaste => const Color(0xFFF59E0B),
        PatternType.moodTrend => cs.primary,
        PatternType.activityMoodLink => const Color(0xFF10B981),
        PatternType.consistency => const Color(0xFF6366F1),
        PatternType.peakProductivity => const Color(0xFFEC4899),
        PatternType.suggestion => const Color(0xFF14B8A6),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final color = _color(cs);

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(_icon, size: 18, color: color),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pattern.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    pattern.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (pattern.confidence != null) ...[
                    const SizedBox(height: Spacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pattern.confidence!,
                        minHeight: 3,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Correlation Card ─────────────────────────────────────────────

class _CorrelationCard extends StatelessWidget {
  final MoodActivityCorrelation correlation;

  const _CorrelationCard({required this.correlation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final icon = activityIconForLabel(correlation.activity);
    final actColor = activityColorHexForLabel(correlation.activity);

    final sortedMoods = correlation.moodDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    correlation.activity,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _fmtMin(correlation.totalMinutes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Color(actColor),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (sortedMoods.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: sortedMoods.take(4).map((m) {
                  final emoji = moodEmojiForLabel(m.key);
                  return Text(
                    '$emoji ${m.value}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Narrative Card ───────────────────────────────────────────────

class _NarrativeCard extends StatelessWidget {
  final String narrative;

  const _NarrativeCard({required this.narrative});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Simple markdown-ish rendering: bold, headers, bullets
    final lines = narrative.split('\n');

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) => _renderLine(line, theme, cs)).toList(),
        ),
      ),
    );
  }

  Widget _renderLine(String line, ThemeData theme, ColorScheme cs) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      return const SizedBox(height: Spacing.sm);
    }

    // H2 heading
    if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
        child: Text(
          trimmed.substring(3),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      );
    }

    // H3 heading
    if (trimmed.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
        child: Text(
          trimmed.substring(4),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      );
    }

    // Bullet
    if (trimmed.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: Spacing.md, bottom: Spacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(color: cs.primary)),
            Expanded(
              child: _RichTextLine(
                text: trimmed.substring(2),
                style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      height: 1.5,
                    ) ??
                    const TextStyle(),
                boldColor: cs.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    // Regular paragraph
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: _RichTextLine(
        text: trimmed,
        style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface,
              height: 1.5,
            ) ??
            const TextStyle(),
        boldColor: cs.onSurface,
      ),
    );
  }
}

/// Renders a single line of text with **bold** support.
class _RichTextLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color boldColor;

  const _RichTextLine({
    required this.text,
    required this.style,
    required this.boldColor,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: style.copyWith(
          fontWeight: FontWeight.bold,
          color: boldColor,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    if (spans.isEmpty) {
      return Text(text, style: style);
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Helpers ──────────────────────────────────────────────────────

String _fmtMin(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
