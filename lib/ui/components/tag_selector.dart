import 'package:flutter/material.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/design/tokens.dart';

/// Wrap-based activity tag chips — multi-select toggle.
class TagSelector extends StatelessWidget {
  final List<ActivityTag> selected;
  final ValueChanged<List<ActivityTag>> onChanged;

  const TagSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(ActivityTag tag) {
    final newList = List<ActivityTag>.from(selected);
    if (newList.contains(tag)) {
      newList.remove(tag);
    } else {
      newList.add(tag);
    }
    onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: ActivityTag.values.map((tag) {
        final isSelected = selected.contains(tag);
        final tagColor = Color(tag.colorHex);

        return GestureDetector(
          onTap: () => _toggle(tag),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? tagColor.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected
                    ? tagColor
                    : cs.outlineVariant.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag.icon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  tag.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected ? tagColor : cs.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 12,
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
