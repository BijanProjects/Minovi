import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/ui/screens/entry/entry_provider.dart';
import 'package:chronosense/ui/design/tokens.dart';
import 'package:chronosense/util/time_utils.dart';
import 'package:chronosense/domain/model/models.dart';

class EntryScreen extends ConsumerStatefulWidget {
  final String date;
  final String startTime;
  final String endTime;
  final VoidCallback onBack;

  const EntryScreen({
    super.key,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.onBack,
  });

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _descController;
  late final AnimationController _enterAnim;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  bool _isEditingMoods = false;
  bool _isEditingActions = false;

  static const _moodEmojis = [
    '😊', '😢', '😡', '😰', '😌', '😴', '🥳', '😔', '😍', '😎',
    '🤔', '😩', '😤', '🥺', '😅', '🫠', '😒', '🤩', '😬', '🤗',
    '😓', '😶', '😑', '🥹', '💀', '😇', '🫡', '😵', '🤯', '🫣',
    '😮', '😂', '🥰', '🫢', '😳', '🤢', '🤧', '😷', '🥶', '🥵',
    '😠', '🤬', '😈', '🫥', '😪', '🤤', '😋', '🫤', '🙄', '😏',
  ];

  static const _actionEmojis = [
    '💼', '📚', '💪', '🎨', '🎮', '🍽️', '🚗', '🛌', '🤝', '🏃',
    '🧘', '📱', '🎵', '🛍️', '☕', '🏠', '✈️', '🎯', '📝', '🐕',
    '💊', '🌿', '🏋️', '🎬', '🧹', '🖥️', '🤸', '🚴', '🍳', '📞',
    '🧑‍💻', '🎧', '📖', '🧪', '🪴', '🎤', '🛠️', '🚿', '🧑‍🍳', '💇',
    '🧑‍⚕️', '🗣️', '📸', '🎭', '🚶', '🛒', '✍️', '🧑‍🏫', '🎲', '🧳',
  ];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();

    _enterAnim = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _enterAnim,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterAnim,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
    ));

    _enterAnim.forward();

    // Load entry data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(entryProvider.notifier).loadEntry(
            date: widget.date,
            startTime: widget.startTime,
            endTime: widget.endTime,
          );
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _enterAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entryProvider);
    final notifier = ref.read(entryProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Sync text controller
    if (_descController.text != state.description &&
        !_descController.text.isNotEmpty) {
      _descController.text = state.description;
    }

    // Handle save/delete completion
    ref.listen<EntryUiState>(entryProvider, (prev, next) {
      if (next.isSaved || next.isDeleted) {
        widget.onBack();
      }
      if (prev?.isLoading == true && !next.isLoading) {
        _descController.text = next.description;
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TimeUtils.formatTimeRange(widget.startTime, widget.endTime),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.date,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (state.existingEntry != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              onPressed: () => _showDeleteConfirmation(context, notifier),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(Spacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            Text(
                              'What happened during this time?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: Spacing.md),
                            TextField(
                              controller: _descController,
                              onChanged: notifier.updateDescription,
                              maxLines: null,
                              minLines: 3,
                              maxLength: 5000,
                              decoration: InputDecoration(
                                hintText:
                                    'Describe what you did, how it went, any thoughts...',
                                hintStyle: TextStyle(
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                counterText: '',
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),

                            const SizedBox(height: Spacing.xl),

                            _buildCategorySection(
                              context: context,
                              title: 'How did you feel?',
                              leadingIcon: Icons.edit_outlined,
                              selected: state.moods,
                              categories: state.moodCategories,
                              emojiMap: state.moodEmojiMap,
                              isMood: true,
                              isEditing: _isEditingMoods,
                              onToggleEditing: () {
                                setState(
                                    () => _isEditingMoods = !_isEditingMoods);
                              },
                              onChipTap: notifier.toggleMoodSelection,
                              onChipRemove: notifier.removeMoodCategory,
                              onAddCategory: () => _showAddCategorySheet(
                                context: context,
                                title: 'Add emotion',
                                emojiOptions: _moodEmojis,
                                onSubmit: notifier.addMoodCategory,
                              ),
                              maxSelectionText: '${state.moods.length} / 3',
                            ),

                            const SizedBox(height: Spacing.xl),

                            _buildCategorySection(
                              context: context,
                              title: 'What were you doing?',
                              leadingIcon: Icons.edit_note_outlined,
                              selected: state.tags,
                              categories: state.actionCategories,
                              emojiMap: state.actionEmojiMap,
                              isMood: false,
                              isEditing: _isEditingActions,
                              onToggleEditing: () {
                                setState(() =>
                                    _isEditingActions = !_isEditingActions);
                              },
                              onChipTap: notifier.toggleTagSelection,
                              onChipRemove: notifier.removeActionCategory,
                              onAddCategory: () => _showAddCategorySheet(
                                context: context,
                                title: 'Add activity',
                                emojiOptions: _actionEmojis,
                                onSubmit: notifier.addActionCategory,
                              ),
                            ),

                            const SizedBox(height: Spacing.xxxl),
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom save button ──
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        border: Border(
                          top: BorderSide(color: cs.outlineVariant, width: 1),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: FilledButton(
                          onPressed: notifier.save,
                          child: const Text('Save Entry'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategorySection({
    required BuildContext context,
    required String title,
    required IconData leadingIcon,
    required List<String> selected,
    required List<String> categories,
    required Map<String, String> emojiMap,
    required bool isMood,
    required bool isEditing,
    required VoidCallback onToggleEditing,
    required ValueChanged<String> onChipTap,
    required Future<void> Function(String) onChipRemove,
    required VoidCallback onAddCategory,
    String? maxSelectionText,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            IconButton(
              onPressed: onToggleEditing,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: isEditing ? 'Done editing' : 'Edit categories',
              icon: Icon(
                isEditing ? Icons.done_rounded : leadingIcon,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (maxSelectionText != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  maxSelectionText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        // ── Responsive layout: 3-column dynamic wrap for mobile, free wrap for web ──
        if (isMobile)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final chipW =
                  (constraints.maxWidth - Spacing.sm * 2) / 3;
              return Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  ...categories.map((item) {
                    final isSelected = selected.contains(item);
                    final emoji = emojiMap.containsKey(item)
                        ? emojiMap[item]!
                        : (isMood
                            ? moodEmojiForLabel(item)
                            : activityIconForLabel(item));
                    final chipColor = Color(
                      isMood
                          ? moodColorHexForLabel(item)
                          : activityColorHexForLabel(item),
                    );
                    return SizedBox(
                      width: chipW,
                      child: _buildMobileChip(
                        item: item,
                        isSelected: isSelected,
                        emoji: emoji,
                        chipColor: chipColor,
                        isEditing: isEditing,
                        onTap: () => onChipTap(item),
                        onRemove: () => onChipRemove(item),
                      ),
                    );
                  }),
                  SizedBox(
                    width: chipW,
                    child: GestureDetector(
                      onTap: onAddCategory,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.45),
                          ),
                          color: cs.primary.withValues(alpha: 0.06),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                size: 16, color: cs.primary),
                            const SizedBox(width: Spacing.xs),
                            Text(
                              'Add',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        else
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              ...categories.map((item) {
                final isSelected = selected.contains(item);
                final emoji = emojiMap.containsKey(item)
                    ? emojiMap[item]!
                    : (isMood
                        ? moodEmojiForLabel(item)
                        : activityIconForLabel(item));
                final chipColor = Color(
                  isMood
                      ? moodColorHexForLabel(item)
                      : activityColorHexForLabel(item),
                );
                return _buildCategoryChip(
                  item: item,
                  isSelected: isSelected,
                  emoji: emoji,
                  chipColor: chipColor,
                  isEditing: isEditing,
                  onTap: () => onChipTap(item),
                  onRemove: () => onChipRemove(item),
                );
              }),
              GestureDetector(
                onTap: onAddCategory,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.45),
                    ),
                    color: cs.primary.withValues(alpha: 0.06),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: cs.primary),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Add',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String item,
    required bool isSelected,
    required String emoji,
    required Color chipColor,
    required bool isEditing,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? chipColor.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected
                    ? chipColor
                    : cs.outlineVariant.withValues(alpha: 0.7),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: Spacing.xs),
                Text(
                  item,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected ? chipColor : cs.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isEditing)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileChip({
    required String item,
    required bool isSelected,
    required String emoji,
    required Color chipColor,
    required bool isEditing,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? chipColor.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected
                    ? chipColor
                    : cs.outlineVariant.withValues(alpha: 0.7),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    item,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected ? chipColor : cs.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isEditing)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddCategorySheet({
    required BuildContext context,
    required String title,
    required List<String> emojiOptions,
    required Future<void> Function(String, String) onSubmit,
  }) async {
    final labelCtrl = TextEditingController();
    String pickedEmoji = emojiOptions.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final cs = theme.colorScheme;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.lg,
              Spacing.xl,
              Spacing.lg + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: labelCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    prefixIcon: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Text(
                          pickedEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    hintText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onSubmitted: (v) async {
                    final name = v.trim();
                    if (name.isEmpty) return;
                    await onSubmit(name, pickedEmoji);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  'PICK AN EMOJI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: emojiOptions.map((e) {
                    final sel = e == pickedEmoji;
                    return GestureDetector(
                      onTap: () => setSheetState(() => pickedEmoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: sel
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: sel
                              ? Border.all(color: cs.primary, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final name = labelCtrl.text.trim();
                      if (name.isEmpty) return;
                      await onSubmit(name, pickedEmoji);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    labelCtrl.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, EntryNotifier notifier) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final bottomInset =
            mediaQuery.viewPadding.bottom + mediaQuery.viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.xxl,
            Spacing.xxl,
            Spacing.xxl,
            Spacing.lg + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: Spacing.xl),
              Icon(Icons.delete_outline, size: 48, color: cs.error),
              const SizedBox(height: Spacing.lg),
              Text(
                'Delete this entry?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'This action cannot be undone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: Spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        notifier.delete();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
