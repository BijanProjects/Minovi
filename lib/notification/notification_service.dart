import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:chronosense/core/algorithm/interval_engine.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/util/time_utils.dart';

/// Notification service — mirrors NotificationScheduler.kt
/// Schedules notifications at each slot boundary using delayed show().
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'chronosense_interval';
  static const _channelName = 'Interval Reminders';
  static const _channelDesc = 'Notifications at each check-in interval';

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        enableVibration: true,
      ),
    );
  }

  Future<void> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Schedule notifications for all remaining boundaries today.
  Future<void> scheduleForToday(UserPreferences prefs) async {
    await cancelAll();

    if (!prefs.notificationsEnabled) return;

    final now = DateTime.now();
    final boundaries = IntervalEngine.remainingBoundaries(
      prefs: prefs,
      now: now,
    );

    for (int i = 0; i < boundaries.length && i < 24; i++) {
      final boundary = boundaries[i];
      final delay = boundary.difference(now);
      if (delay.isNegative) continue;

      // Compute the slot that just ended
      final endMin = boundary.hour * 60 + boundary.minute;
      final startMin = endMin - prefs.intervalMinutes;
      final startTime =
          '${(startMin ~/ 60).toString().padLeft(2, '0')}:${(startMin % 60).toString().padLeft(2, '0')}';
      final endTime =
          '${boundary.hour.toString().padLeft(2, '0')}:${boundary.minute.toString().padLeft(2, '0')}';

      final body =
          'How was ${TimeUtils.formatTimeRange(startTime, endTime)}?';

      // Schedule using delayed Future.
      // For production-grade exact alarms, integrate the timezone package
      // and use zonedSchedule instead.
      Future.delayed(delay, () {
        _plugin.show(
          i,
          'Time to reflect ✨',
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              enableVibration: true,
              autoCancel: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      });
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  void _onNotificationTap(NotificationResponse response) {
    // App opens to main screen on notification tap
  }
}
