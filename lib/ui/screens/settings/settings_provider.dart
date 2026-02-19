import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/core/di/refresh_signal.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/notification/notification_service.dart';

// ── State ──
class SettingsUiState {
  final UserPreferences prefs;
  final bool isLoading;

  const SettingsUiState({
    this.prefs = const UserPreferences(),
    this.isLoading = true,
  });

  SettingsUiState copyWith({
    UserPreferences? prefs,
    bool? isLoading,
  }) {
    return SettingsUiState(
      prefs: prefs ?? this.prefs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ──
class SettingsNotifier extends Notifier<SettingsUiState> {
  @override
  SettingsUiState build() {
    Future.microtask(_load);
    return const SettingsUiState();
  }

  Future<void> _load() async {
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final prefs = await prefsRepo.getPreferences();
    state = SettingsUiState(prefs: prefs, isLoading: false);
  }

  Future<void> updateWakeTime(int hour, int minute) async {
    final updated = state.prefs.copyWith(wakeHour: hour, wakeMinute: minute);
    await _saveAndSchedule(updated);
  }

  Future<void> updateSleepTime(int hour, int minute) async {
    final updated = state.prefs.copyWith(sleepHour: hour, sleepMinute: minute);
    await _saveAndSchedule(updated);
  }

  Future<void> updateInterval(int minutes) async {
    final oldInterval = state.prefs.intervalMinutes;
    final now = DateTime.now().toIso8601String();
    final updated = state.prefs.copyWith(
      intervalMinutes: minutes,
      previousIntervalMinutes: oldInterval,
      intervalChangedAt: now,
    );
    await _saveAndSchedule(updated);
  }

  Future<void> toggleNotifications(bool enabled) async {
    final updated = state.prefs.copyWith(notificationsEnabled: enabled);
    await _saveAndSchedule(updated);
  }

  Future<void> _saveAndSchedule(UserPreferences updated) async {
    state = state.copyWith(prefs: updated);
    print('SettingsNotifier._saveAndSchedule: prefs updated -> ${updated.toString()}');
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    await prefsRepo.updatePreferences((_) => updated);

    // Reschedule notifications
    if (updated.notificationsEnabled) {
      print('SettingsNotifier._saveAndSchedule: notifications enabled — scheduling for today');
      await NotificationService.instance.scheduleForToday(updated);
    } else {
      print('SettingsNotifier._saveAndSchedule: notifications disabled — cancelling');
      await NotificationService.instance.cancelAll();
    }

    // Signal other providers to refresh.
    ref.read(refreshSignalProvider.notifier).notify();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsUiState>(
  SettingsNotifier.new,
);
