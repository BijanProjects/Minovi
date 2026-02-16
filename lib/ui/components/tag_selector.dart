import 'package:flutter/material.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/design/tokens.dart';

/// Horizontal scrollable row of 10 FilterChips — multi-select toggle.
class TagSelector extends StatelessWidget {
  final List<ActivityTag> selected;
  final ValueChanged<List<ActivityTag>> onChanged;

  const TagSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        itemCount: ActivityTag.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          final tag = ActivityTag.values[index];
          final isSelected = selected.contains(tag);

          return FilterChip(
            label: Text('${tag.icon} ${tag.label}'),
            selected: isSelected,
            onSelected: (value) {
              final newList = List<ActivityTag>.from(selected);
              if (value) {
                newList.add(tag);
              } else {
                newList.remove(tag);
              }
              onChanged(newList);
            },
            selectedColor: Theme.of(context).colorScheme.primary,
            checkmarkColor: Theme.of(context).colorScheme.onPrimary,
            showCheckmark: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          );
        },
      ),
    );
  }
}
