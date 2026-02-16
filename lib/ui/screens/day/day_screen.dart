import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/ui/screens/day/day_provider.dart';
import 'package:chronosense/ui/components/time_slot_card.dart';
import 'package:chronosense/ui/design/tokens.dart';
import 'package:chronosense/util/time_utils.dart';

class DayScreen extends ConsumerStatefulWidget {
  final void Function(String date, String startTime, String endTime) onSlotTap;

  const DayScreen({super.key, required this.onSlotTap});

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _hasAutoScrolled = false;
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
    _scrollController.dispose();
    super.dispose();
  }

  // ── Navigation ──

  void _navigateDay({required bool forward}) {
    if (_settling) {
      _settling = false;
      _settleController.stop();
    }
    final screenW = MediaQuery.of(context).size.width;
    _animateTo(forward ? -screenW : screenW, onComplete: () {
      ref.read(dayProvider.notifier).navigateInstant(forward: forward);
      setState(() => _dragOffset = 0);
      _hasAutoScrolled = false;
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
    final shouldCommit =
        velocity.abs() > 300 || _dragOffset.abs() > threshold;

    if (shouldCommit) {
      final forward =
          velocity.abs() > 300 ? velocity < 0 : _dragOffset < 0;
      _animateTo(forward ? -screenW : screenW, onComplete: () {
        ref.read(dayProvider.notifier).navigateInstant(forward: forward);
        setState(() => _dragOffset = 0);
        _hasAutoScrolled = false;
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

  void _autoScrollToActiveSlot(DayUiState state) {
    if (!_hasAutoScrolled && state.isToday && state.activeSlotIndex >= 0) {
      _hasAutoScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final target = state.activeSlotIndex * 88.0;
          final clampedTarget = target.clamp(0.0, _scrollController.position.maxScrollExtent);
          final current = _scrollController.offset;
          if ((current - clampedTarget).abs() > 2) {
            _scrollController.animateTo(
              clampedTarget,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dayProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    _autoScrollToActiveSlot(state);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (fixed — does not move with swipe) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl, Spacing.lg, Spacing.xl, Spacing.sm,
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

          const SizedBox(height: Spacing.md),

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
                        // Previous day
                        if (state.prevDay != null)
                          _positioned(
                            offset: _dragOffset - w,
                            width: w,
                            child: _buildDayPanel(
                                state.prevDay!, theme, cs),
                          ),
                        // Current day
                        _positioned(
                          offset: _dragOffset,
                          width: w,
                          child: _buildDayPanel(
                              state, theme, cs, isCenter: true),
                        ),
                        // Next day
                        if (state.nextDay != null)
                          _positioned(
                            offset: _dragOffset + w,
                            width: w,
                            child: _buildDayPanel(
                                state.nextDay!, theme, cs),
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

  Widget _buildDayPanel(
    DayUiState dayState,
    ThemeData theme,
    ColorScheme cs, {
    bool isCenter = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date navigation row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed:
                    isCenter ? () => _navigateDay(forward: false) : null,
                style: IconButton.styleFrom(
                  foregroundColor: cs.onSurface,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      dayState.formattedDate,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      '${(dayState.completionRate * 100).round()}% logged',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    isCenter ? () => _navigateDay(forward: true) : null,
                style: IconButton.styleFrom(
                  foregroundColor: cs.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xl,
            vertical: Spacing.sm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: dayState.completionRate,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ),

        const SizedBox(height: Spacing.sm),

        // Time slot list
        Expanded(
          child: dayState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : dayState.timeSlots.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      controller:
                          isCenter ? _scrollController : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg,
                        vertical: Spacing.sm,
                      ),
                      itemCount: dayState.timeSlots.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: Spacing.sm + 2),
                      itemBuilder: (context, index) {
                        final slot = dayState.timeSlots[index];
                        return TimeSlotCard(
                          slot: slot,
                          index: index,
                          onTap: isCenter
                              ? () {
                                  final dateStr =
                                      TimeUtils.toIsoDate(dayState.date);
                                  widget.onSlotTap(
                                    dateStr,
                                    slot.startTime,
                                    slot.endTime,
                                  );
                                }
                              : () {},
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⏰', style: TextStyle(fontSize: 48)),
          const SizedBox(height: Spacing.lg),
          Text(
            'No time slots for this day',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Set up your waking hours in Settings',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
