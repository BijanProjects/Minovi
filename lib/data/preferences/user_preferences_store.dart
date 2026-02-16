import 'package:shared_preferences/shared_preferences.dart';
import 'package:chronosense/domain/model/models.dart';

/// Persists user preferences using SharedPreferences.
class UserPreferencesStore {
  UserPreferencesStore._();
  static final UserPreferencesStore instance = UserPreferencesStore._();

  static const _wakeHour = 'wake_hour';
  static const _wakeMinute = 'wake_minute';
  static const _sleepHour = 'sleep_hour';
  static const _sleepMinute = 'sleep_minute';
  static const _intervalMinutes = 'interval_minutes';
  static const _notificationsEnabled = 'notifications_enabled';
  static const _dynamicColors = 'dynamic_colors';

  Future<UserPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserPreferences(
      wakeHour: prefs.getInt(_wakeHour) ?? 7,
      wakeMinute: prefs.getInt(_wakeMinute) ?? 0,
      sleepHour: prefs.getInt(_sleepHour) ?? 23,
      sleepMinute: prefs.getInt(_sleepMinute) ?? 0,
      intervalMinutes: prefs.getInt(_intervalMinutes) ?? 120,
      notificationsEnabled: prefs.getBool(_notificationsEnabled) ?? true,
      dynamicColors: prefs.getBool(_dynamicColors) ?? false,
    );
  }

  Future<void> save(UserPreferences p) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(_wakeHour, p.wakeHour),
      prefs.setInt(_wakeMinute, p.wakeMinute),
      prefs.setInt(_sleepHour, p.sleepHour),
      prefs.setInt(_sleepMinute, p.sleepMinute),
      prefs.setInt(_intervalMinutes, p.intervalMinutes),
      prefs.setBool(_notificationsEnabled, p.notificationsEnabled),
      prefs.setBool(_dynamicColors, p.dynamicColors),
    ]);
  }
}
