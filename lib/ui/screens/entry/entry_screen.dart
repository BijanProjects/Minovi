import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/ui/screens/entry/entry_provider.dart';
import 'package:chronosense/ui/components/mood_selector.dart';
import 'package:chronosense/ui/components/tag_selector.dart';
import 'package:chronosense/ui/design/tokens.dart';
import 'package:chronosense/util/time_utils.dart';

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
    if (_descController.text != state.description && !_descController.text.isNotEmpty) {
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
                                hintText: 'Describe what you did, how it went, any thoughts...',
                                hintStyle: TextStyle(
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                counterText: '',
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),

                            const SizedBox(height: Spacing.xl),

                            // Mood
                            MoodSelector(
                              selected: state.moods,
                              onChanged: notifier.updateMoods,
                            ),

                            const SizedBox(height: Spacing.xl),

                            // Tags
                            Text(
                              'What were you doing?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: Spacing.md),
                            TagSelector(
                              selected: state.tags,
                              onChanged: notifier.updateTags,
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

  void _showDeleteConfirmation(BuildContext context, EntryNotifier notifier) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
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
            const SizedBox(height: Spacing.xxl),
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
            const SizedBox(height: Spacing.xxl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
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
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}
