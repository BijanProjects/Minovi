import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/design/tokens.dart';
import 'package:chronosense/util/time_utils.dart';
import 'package:flutter/material.dart';

/// Card showing a time slot with mood accent bar, description preview, and tags.
class TimeSlotCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filled = slot.isFilled;
    final entry = slot.entry;
    final moodColor = entry?.moods.isNotEmpty == true
        ? Color(moodColorHexForLabel(entry!.moods.first))
        : cs.outlineVariant;

    return Card(
      elevation: filled ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      color: filled
          ? cs.surface
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(
          children: [
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
    );
  }

  Widget _buildFilledContent(BuildContext context, JournalEntry entry) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TimeUtils.formatTimeRange(slot.startTime, slot.endTime),
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (entry.moods.isNotEmpty) ...[
              Text(
                entry.moods.map(moodEmojiForLabel).join(' '),
                style: theme.textTheme.titleLarge,
              ),
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

  Widget _buildTagChips(BuildContext context, List<String> tags) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayTags = tags.take(3).toList();
    final overflow = tags.length - 3;

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        ...displayTags.map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xxs,
            ),
            decoration: BoxDecoration(
              color:
                  Color(activityColorHexForLabel(tag)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '${activityIconForLabel(tag)} $tag',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Color(activityColorHexForLabel(tag)),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
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
                TimeUtils.formatTimeRange(slot.startTime, slot.endTime),
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
