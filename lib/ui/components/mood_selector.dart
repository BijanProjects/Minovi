import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/design/tokens.dart';

/// 2-column grid of 10 animated mood chips — multi-select up to 3.
class MoodSelector extends StatelessWidget {
  final List<Mood> selected;
  final ValueChanged<List<Mood>> onChanged;
  static const int _maxSelections = 3;

  const MoodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(Mood mood) {
    final current = List<Mood>.from(selected);
    if (current.contains(mood)) {
      current.remove(mood);
    } else {
      if (current.length >= _maxSelections) return;
      current.add(mood);
    }
    HapticFeedback.lightImpact();
    onChanged(current);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'How did you feel?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: selected.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${selected.length} / $_maxSelections',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          children: Mood.values.map((mood) {
            final isSelected = selected.contains(mood);
            final isDisabled =
                !isSelected && selected.length >= _maxSelections;
            return SizedBox(
              width: (MediaQuery.of(context).size.width - Spacing.xl * 2 - Spacing.md) / 2,
              child: _MoodChip(
                mood: mood,
                isSelected: isSelected,
                isDisabled: isDisabled,
                onTap: () => _toggle(mood),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MoodChip extends StatefulWidget {
  final Mood mood;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_MoodChip old) {
    super.didUpdateWidget(old);
    if (old.isSelected != widget.isSelected) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final target = widget.isSelected ? 1.04 : 1.0;

    _scaleAnimation = Tween<double>(
      begin: widget.isSelected ? 1.0 : 1.04,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.duration = const Duration(milliseconds: 600);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moodColor = Color(widget.mood.colorHex);

    return _SpringAnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm + Spacing.xxs,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? moodColor.withValues(alpha: 0.14)
                : widget.isDisabled
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.38)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: widget.isSelected
                  ? moodColor
                  : widget.isDisabled
                      ? cs.outlineVariant.withValues(alpha: 0.4)
                      : cs.outlineVariant,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.mood.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  widget.mood.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.isSelected
                            ? moodColor
                            : widget.isDisabled
                                ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                                : cs.onSurface,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                ),
              ),
              if (widget.isSelected)
                Icon(Icons.check_circle, size: 18, color: moodColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpringAnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const _SpringAnimatedBuilder({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
