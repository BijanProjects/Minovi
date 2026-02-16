import 'package:flutter/material.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/design/tokens.dart';

/// 3-column grid of activity tags — multi-select toggle.
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        childAspectRatio: 2.6,
      ),
      itemCount: ActivityTag.values.length,
      itemBuilder: (context, index) {
        final tag = ActivityTag.values[index];
        final isSelected = selected.contains(tag);
        final tagColor = Color(tag.colorHex);

        return Material(
          color: isSelected
              ? tagColor.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _toggle(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? tagColor : cs.outlineVariant.withValues(alpha: 0.5),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Flexible(
                    child: Text(
                      tag.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected ? tagColor : cs.onSurfaceVariant,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
