import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/ui/screens/settings/settings_provider.dart';
import 'package:chronosense/ui/design/tokens.dart';
import 'package:chronosense/util/time_utils.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefs = state.prefs;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Spacing.lg),

            Text(
              'Settings',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.xxl),

            // ── SCHEDULE SECTION ──
            Text(
              'SCHEDULE',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Spacing.md),

            // Wake time
            _TimeCard(
              emoji: '☀️',
              label: 'Wake Time',
              value: _format12h(prefs.wakeHour, prefs.wakeMinute),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: prefs.wakeHour,
                    minute: prefs.wakeMinute,
                  ),
                );
                if (time != null) {
                  notifier.updateWakeTime(time.hour, time.minute);
                }
              },
            ),
            const SizedBox(height: Spacing.md),

            // Sleep time
            _TimeCard(
              emoji: '🌙',
              label: 'Sleep Time',
              value: _format12h(prefs.sleepHour, prefs.sleepMinute),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: prefs.sleepHour,
                    minute: prefs.sleepMinute,
                  ),
                );
                if (time != null) {
                  notifier.updateSleepTime(time.hour, time.minute);
                }
              },
            ),
            const SizedBox(height: Spacing.lg),

            // Interval selector
            Row(
              children: [
                const Text('⏱', style: TextStyle(fontSize: 20)),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Check-in Interval',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: UserPreferences.intervalOptions.map((min) {
                final isSelected = prefs.intervalMinutes == min;
                return FilterChip(
                  label: Text(TimeUtils.formatIntervalLabel(min)),
                  selected: isSelected,
                  onSelected: (_) => notifier.updateInterval(min),
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.primary,
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSelected ? cs.primary : cs.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: Spacing.xxxl),

            // ── NOTIFICATIONS SECTION ──
            Text(
              'NOTIFICATIONS',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Spacing.md),

            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: cs.onSurface,
                    size: 24,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interval Reminders',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          'Get notified at each interval',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: prefs.notificationsEnabled,
                    onChanged: notifier.toggleNotifications,
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return cs.onPrimary;
                      }
                      return null;
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return cs.primary;
                      }
                      return null;
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.xxxl),

            // ── ABOUT SECTION ──
            Text(
              'ABOUT',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Spacing.md),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withAlpha(20),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // App Icon in God Mode
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withAlpha(46),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Minovi',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Version 1.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Understand your time. Reflect on your hours. Live intentionally.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.huge),
          ],
        ),
      ),
    );
  }

  static String _format12h(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${h.toString()}:${minute.toString().padLeft(2, '0')} $period';
  }
}

class _TimeCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
