import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/screens/month/month_provider.dart';
import 'package:chronosense/ui/design/tokens.dart';

class MonthScreen extends ConsumerStatefulWidget {
  final void Function(DateTime date)? onDayTap;

  const MonthScreen({super.key, this.onDayTap});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _settleController;
  double _dragOffset = 0;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  // ── Navigation ──

  void _navigateMonth({required bool forward}) {
    if (_settling) {
      _settling = false;
      _settleController.stop();
    }
    final screenW = MediaQuery.of(context).size.width;
    _animateTo(forward ? -screenW : screenW, onComplete: () {
      ref.read(monthProvider.notifier).navigateInstant(forward: forward);
      setState(() => _dragOffset = 0);
    });
  }

  // ── Drag handling ──

  void _onDragUpdate(DragUpdateDetails details) {
    if (_settling) {
      _settling = false;
      _settleController.stop();
    }
    setState(() => _dragOffset += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final screenW = MediaQuery.of(context).size.width;
    final threshold = screenW * 0.25;
    final shouldCommit = velocity.abs() > 300 || _dragOffset.abs() > threshold;

    if (shouldCommit) {
      final forward = velocity.abs() > 300 ? velocity < 0 : _dragOffset < 0;
      _animateTo(forward ? -screenW : screenW, onComplete: () {
        ref.read(monthProvider.notifier).navigateInstant(forward: forward);
        setState(() => _dragOffset = 0);
      });
    } else {
      _animateTo(0);
    }
  }

  /// Animate [_dragOffset] to [target]. Calls [onComplete] on finish
  /// unless the animation was interrupted by a new drag.
  Future<void> _animateTo(double target, {VoidCallback? onComplete}) async {
    final from = _dragOffset;
    if ((from - target).abs() < 1) {
      setState(() => _dragOffset = target);
      onComplete?.call();
      return;
    }

    _settling = true;
    final screenW = MediaQuery.of(context).size.width;
    final distance = (target - from).abs();
    final ms = (250 * distance / screenW).clamp(100, 300).toInt();
    _settleController.duration = Duration(milliseconds: ms);

    final anim = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    void listener() {
      if (!mounted) return;
      setState(() => _dragOffset = anim.value);
    }

    _settleController.addListener(listener);
    _settleController.reset();
    await _settleController.forward();
    _settleController.removeListener(listener);

    if (mounted && _settling) {
      setState(() => _dragOffset = target);
      onComplete?.call();
    }
    _settling = false;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final isCurrentMonth =
        state.month.year == now.year && state.month.month == now.month;
    final currentMonthLabel =
        isCurrentMonth ? 'This Month' : state.formattedMonth;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App Header (fixed) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.lg,
              Spacing.xl,
              Spacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  'Minovi',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ── Monthly Overview Header (fixed) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.md,
              Spacing.xl,
              Spacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Overview',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentMonthLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isCurrentMonth)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(monthProvider.notifier).goToCurrentMonth(),
                        icon: const Icon(Icons.my_location_outlined, size: 18),
                        label: const Text('Go to This Month'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Swipeable 3-panel viewport ──
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              behavior: HitTestBehavior.translucent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return ClipRect(
                    child: Stack(
                      children: [
                        // Previous month
                        if (state.prevMonth != null)
                          _positioned(
                            offset: _dragOffset - w,
                            width: w,
                            child: _buildMonthPanel(state.prevMonth!, theme, cs,
                                showHeader: false),
                          ),
                        // Current month
                        _positioned(
                          offset: _dragOffset,
                          width: w,
                          child: _buildMonthPanel(state, theme, cs,
                              isCenter: true, showHeader: false),
                        ),
                        // Next month
                        if (state.nextMonth != null)
                          _positioned(
                            offset: _dragOffset + w,
                            width: w,
                            child: _buildMonthPanel(state.nextMonth!, theme, cs,
                                showHeader: false),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positioned({
    required double offset,
    required double width,
    required Widget child,
  }) {
    return Positioned(
      left: offset,
      top: 0,
      bottom: 0,
      width: width,
      child: child,
    );
  }

  Widget _buildMonthPanel(
    MonthUiState monthState,
    ThemeData theme,
    ColorScheme cs, {
    bool isCenter = false,
    bool showHeader = true,
  }) {
    if (monthState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.lg),
          if (showHeader) ...[
            // ── Header ──
            Text(
              'Monthly Overview',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.xl),
          ],
          // ── Month navigation ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed:
                    isCenter ? () => _navigateMonth(forward: false) : null,
              ),
              Text(
                monthState.formattedMonth,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    isCenter ? () => _navigateMonth(forward: true) : null,
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),

          // ── Calendar grid ──
          _CalendarGrid(
            month: monthState.month,
            daysWithEntries: monthState.insight?.daysWithEntries ?? {},
            onDayTap: isCenter ? widget.onDayTap : null,
          ),
          const SizedBox(height: Spacing.xxl),

          if (monthState.insight != null &&
              monthState.insight!.totalEntries > 0) ...[
            _SummaryCard(insight: monthState.insight!),
            const SizedBox(height: Spacing.xl),
            if (monthState.insight!.moodFrequency.isNotEmpty) ...[
              Text(
                'Mood Distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.md),
              _MoodDistribution(moods: monthState.insight!.moodFrequency),
              const SizedBox(height: Spacing.xl),
            ],
            if (monthState.insight!.tagFrequency.isNotEmpty) ...[
              Text(
                'Most Repeated Activities',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.md),
              _ActivityChart(tags: monthState.insight!.tagFrequency),
            ],
          ] else
            _buildEmptyState(context),

          const SizedBox(height: Spacing.xxxl),
        ],
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
            value: insight.topActivity ?? '—',
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
  final Map<String, int> moods;

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
              color: Color(moodColorHexForLabel(entry.key))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  moodEmojiForLabel(entry.key),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  '${entry.value}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Color(moodColorHexForLabel(entry.key)),
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
  final Map<String, int> tags;

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
                      Text(activityIconForLabel(entry.key),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: Spacing.xs),
                      Flexible(
                        child: Text(
                          entry.key,
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
                          color:
                              cs.surfaceContainerHighest.withValues(alpha: 0.5),
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
