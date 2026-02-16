import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/screens/month/month_provider.dart';
import 'package:chronosense/ui/design/tokens.dart';

class MonthScreen extends ConsumerWidget {
  final void Function(DateTime date)? onDayTap;

  const MonthScreen({super.key, this.onDayTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monthProvider);
    final notifier = ref.read(monthProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Spacing.lg),

                  // ── Header ──
                  Text(
                    'Monthly Overview',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),

                  // ── Month navigation ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: notifier.previousMonth,
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                        child: Text(
                          state.formattedMonth,
                          key: ValueKey(state.formattedMonth),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: notifier.nextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),

                  // ── Calendar grid ──
                  _CalendarGrid(
                    month: state.month,
                    daysWithEntries: state.insight?.daysWithEntries ?? {},
                    onDayTap: onDayTap,
                  ),
                  const SizedBox(height: Spacing.xxl),

                  if (state.insight != null && state.insight!.totalEntries > 0) ...[
                    // ── Summary stats ──
                    _SummaryCard(insight: state.insight!),
                    const SizedBox(height: Spacing.xl),

                    // ── Mood distribution ──
                    if (state.insight!.moodFrequency.isNotEmpty) ...[
                      Text(
                        'Mood Distribution',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      _MoodDistribution(moods: state.insight!.moodFrequency),
                      const SizedBox(height: Spacing.xl),
                    ],

                    // ── Activity chart ──
                    if (state.insight!.tagFrequency.isNotEmpty) ...[
                      Text(
                        'Most Repeated Activities',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      _ActivityChart(tags: state.insight!.tagFrequency),
                    ],
                  ] else
                    _buildEmptyState(context),

                  const SizedBox(height: Spacing.xxxl),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.huge),
        child: Column(
          children: [
            const Text('📊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: Spacing.lg),
            Text(
              'No entries this month yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Start logging your time to see insights here',
              style: theme.textTheme.bodyMedium?.copyWith(
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

// ── Calendar Grid ──────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<int> daysWithEntries;
  final void Function(DateTime)? onDayTap;

  const _CalendarGrid({
    required this.month,
    required this.daysWithEntries,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-start: Monday=0..Sunday=6
    final startWeekday = (firstDay.weekday - 1) % 7;

    final headers = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Column(
      children: [
        // Day-of-week headers
        Row(
          children: headers
              .map((h) => Expanded(
                    child: Center(
                      child: Text(
                        h,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: Spacing.sm),
        // Day grid
        ...List.generate(6, (week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: List.generate(7, (weekday) {
                final dayIndex = week * 7 + weekday - startWeekday + 1;
                if (dayIndex < 1 || dayIndex > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }

                final date = DateTime(month.year, month.month, dayIndex);
                final isToday = date == today;
                final hasEntry = daysWithEntries.contains(dayIndex);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap?.call(date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isToday
                            ? cs.primary
                            : hasEntry
                                ? cs.primaryContainer
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayIndex',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isToday
                              ? cs.onPrimary
                              : hasEntry
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface,
                          fontWeight:
                              isToday || hasEntry ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

// ── Summary Card ───────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final MonthInsight insight;

  const _SummaryCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _StatColumn(
            value: '${insight.totalEntries}',
            label: 'Entries',
            theme: theme,
          ),
          _StatColumn(
            value: '${insight.activeDays}',
            label: 'Active Days',
            theme: theme,
          ),
          _StatColumn(
            value: insight.topActivity?.label ?? '—',
            label: 'Top Activity',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final ThemeData theme;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Mood Distribution ──────────────────────────────────────────────
class _MoodDistribution extends StatelessWidget {
  final Map<Mood, int> moods;

  const _MoodDistribution({required this.moods});

  @override
  Widget build(BuildContext context) {
    final total = moods.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sorted = moods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: sorted.map((entry) {
        final fraction = entry.value / total;
        return Expanded(
          flex: (fraction * 100).round().clamp(1, 100),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(
              vertical: Spacing.md,
              horizontal: Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: Color(entry.key.colorHex).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(entry.key.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: Spacing.xxs),
                Text(
                  '${entry.value}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Color(entry.key.colorHex),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Activity Chart ─────────────────────────────────────────────────
class _ActivityChart extends StatelessWidget {
  final Map<ActivityTag, int> tags;

  const _ActivityChart({required this.tags});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sorted = tags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final display = sorted.take(8).toList();
    final maxVal = display.first.value;

    return Column(
      children: display.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final entry = mapEntry.value;
        final fraction = maxVal > 0 ? entry.value / maxVal : 0.0;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction),
          duration: Duration(milliseconds: 500 + index * 80),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Row(
                    children: [
                      Text(entry.key.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: Spacing.xs),
                      Flexible(
                        child: Text(
                          entry.key.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: Spacing.sm),
                          child: Text(
                            '${entry.value}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
