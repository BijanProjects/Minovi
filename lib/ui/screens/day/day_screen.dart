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
  bool _isAnimating = false;

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

  /// Smoothly animate [_dragOffset] from [from] to [to].
  Future<void> _animateOffset(double from, double to,
      {Curve curve = Curves.easeOutCubic}) async {
    final screenW = MediaQuery.of(context).size.width;
    final distance = (to - from).abs();
    final ms = (300 * distance / screenW).clamp(100, 350).toInt();
    _settleController.duration = Duration(milliseconds: ms);

    final anim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _settleController, curve: curve),
    );
    void listener() => setState(() => _dragOffset = anim.value);
    _settleController.addListener(listener);
    _settleController.reset();
    await _settleController.forward();
    _settleController.removeListener(listener);
    _dragOffset = to;
  }

  /// Arrow-button navigation (full slide out → change → slide in).
  Future<void> _swipeNavigate({required bool forward}) async {
    if (_isAnimating) return;
    _isAnimating = true;

    final screenW = MediaQuery.of(context).size.width;
    final notifier = ref.read(dayProvider.notifier);

    await _animateOffset(0, forward ? -screenW : screenW,
        curve: Curves.easeInCubic);

    if (forward) {
      notifier.nextDay();
    } else {
      notifier.previousDay();
    }

    setState(() => _dragOffset = forward ? screenW : -screenW);
    await _animateOffset(_dragOffset, 0);

    _isAnimating = false;
    _hasAutoScrolled = false;
  }

  /// Called when the user lifts their finger after dragging.
  void _onDragEnd(DragEndDetails details) async {
    if (_isAnimating) return;
    _isAnimating = true;

    final velocity = details.primaryVelocity ?? 0;
    final screenW = MediaQuery.of(context).size.width;
    final threshold = screenW * 0.25;
    final shouldCommit = velocity.abs() > 300 || _dragOffset.abs() > threshold;

    if (shouldCommit) {
      final forward = velocity.abs() > 300 ? velocity < 0 : _dragOffset < 0;
      await _animateOffset(_dragOffset, forward ? -screenW : screenW);

      final notifier = ref.read(dayProvider.notifier);
      if (forward) {
        notifier.nextDay();
      } else {
        notifier.previousDay();
      }

      setState(() => _dragOffset = forward ? screenW : -screenW);
      await _animateOffset(_dragOffset, 0);
      _hasAutoScrolled = false;
    } else {
      await _animateOffset(_dragOffset, 0);
    }

    _isAnimating = false;
  }

  void _autoScrollToActiveSlot(DayUiState state) {
    if (!_hasAutoScrolled && state.isToday && state.activeSlotIndex >= 0) {
      _hasAutoScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final target = state.activeSlotIndex * 88.0; // approx card height
          _scrollController.animateTo(
            target.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dayProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    _autoScrollToActiveSlot(state);

    return GestureDetector(
      onHorizontalDragUpdate: _isAnimating
          ? null
          : (details) => setState(() => _dragOffset += details.delta.dx),
      onHorizontalDragEnd: _isAnimating ? null : _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── Header ──
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

          // ── Date navigation row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _swipeNavigate(forward: false),
                  style: IconButton.styleFrom(
                    foregroundColor: cs.onSurface,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        ),
                        child: Text(
                          state.formattedDate,
                          key: ValueKey(state.formattedDate),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          '${(state.completionRate * 100).round()}% logged',
                          key: ValueKey(state.completionRate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _swipeNavigate(forward: true),
                  style: IconButton.styleFrom(
                    foregroundColor: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: Spacing.sm,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: state.completionRate),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
            ),
          ),

          const SizedBox(height: Spacing.sm),

          // ── Time slot list ──
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.timeSlots.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.lg,
                          vertical: Spacing.sm,
                        ),
                        itemCount: state.timeSlots.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Spacing.sm + 2),
                        itemBuilder: (context, index) {
                          final slot = state.timeSlots[index];
                          return TimeSlotCard(
                            slot: slot,
                            index: index,
                            onTap: () {
                              final dateStr = TimeUtils.toIsoDate(state.date);
                              widget.onSlotTap(
                                dateStr,
                                slot.startTime,
                                slot.endTime,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
    ),
    ),
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
