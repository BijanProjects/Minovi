import 'package:flutter/material.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/design/tokens.dart';
import 'package:chronosense/util/time_utils.dart';

/// Card showing a time slot — mood accent bar, description preview, tag chips.
/// Staggered fade+slide animation on appearance.
class TimeSlotCard extends StatefulWidget {
  final TimeSlot slot;
  final int index;
  final VoidCallback onTap;

  const TimeSlotCard({
    super.key,
    required this.slot,
    required this.index,
    required this.onTap,
  });

  @override
  State<TimeSlotCard> createState() => _TimeSlotCardState();
}

class _TimeSlotCardState extends State<TimeSlotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final delay = (widget.index * 0.06).clamp(0.0, 0.5);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(curved);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filled = widget.slot.isFilled;
    final entry = widget.slot.entry;
    final moodColor = entry?.mood != null
        ? Color(entry!.mood!.colorHex)
        : cs.outlineVariant;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Card(
          elevation: filled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          color: filled
              ? cs.surface
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Row(
              children: [
                // ── Mood accent bar ──
                Container(
                  width: 4,
                  height: filled ? 90 : 72,
                  decoration: BoxDecoration(
                    color: moodColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(AppRadius.lg),
                    ),
                  ),
                ),
                // ── Content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: filled
                        ? _buildFilledContent(context, entry!)
                        : _buildEmptyContent(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilledContent(BuildContext context, JournalEntry entry) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time range
        Text(
          TimeUtils.formatTimeRange(widget.slot.startTime, widget.slot.endTime),
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        // Mood emoji + description inline
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (entry.mood != null) ...[
              Text(entry.mood!.emoji,
                  style: theme.textTheme.titleLarge),
              const SizedBox(width: Spacing.sm),
            ],
            Expanded(
              child: Text(
                entry.description.isEmpty
                    ? 'No description'
                    : entry.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (entry.tags.isNotEmpty) ...[
          const SizedBox(height: Spacing.xs + Spacing.xxs),
          _buildTagChips(context, entry.tags),
        ],
      ],
    );
  }

  Widget _buildTagChips(BuildContext context, List<ActivityTag> tags) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayTags = tags.take(3).toList();
    final overflow = tags.length - 3;

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        ...displayTags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: Color(tag.colorHex).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${tag.icon} ${tag.label}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Color(tag.colorHex),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )),
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xxs,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '+$overflow',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TimeUtils.formatTimeRange(
                    widget.slot.startTime, widget.slot.endTime),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.add,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 18,
                  ),
                  const SizedBox(width: Spacing.xs + Spacing.xxs),
                  Text(
                    'Tap to record this interval',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
