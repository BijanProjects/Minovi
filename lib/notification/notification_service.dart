import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (kIsWeb) {
      print('NotificationService.initialize: running on web — skipping native initialization.');
      return;
    }
    print('NotificationService.initialize: initializing native plugin.');
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
      settings: settings,
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
    if (kIsWeb) {
      print('NotificationService.requestPermission: web — no-op');
      return;
    }
    print('NotificationService.requestPermission: requesting Android notifications permission');
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Schedule notifications for all remaining boundaries today.
  Future<void> scheduleForToday(UserPreferences prefs) async {
    if (kIsWeb) {
      print('NotificationService.scheduleForToday: web — no-op (prefs=${prefs.toString()})');
      return;
    }

    print('NotificationService.scheduleForToday: called with prefs=${prefs.toString()}');
    await cancelAll();

    if (!prefs.notificationsEnabled) {
      print('NotificationService.scheduleForToday: notifications disabled in prefs — returning');
      return;
    }

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
      print('NotificationService.scheduleForToday: scheduling notification #$i in ${delay.inSeconds}s — body="$body"');
      Future.delayed(delay, () async {
        try {
          await _plugin.show(
            id: i,
            title: 'Time to reflect ✨',
            body: body,
            notificationDetails: const NotificationDetails(
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
          print('NotificationService: showed notification id=$i');
        } catch (e, st) {
          print('NotificationService: error showing notification id=$i -> $e');
          print(st);
        }
      });
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      print('NotificationService.cancelAll: web — no-op');
      return;
    }
    print('NotificationService.cancelAll: cancelling notifications');
    await _plugin.cancelAll();
  }

  void _onNotificationTap(NotificationResponse response) {
    // App opens to main screen on notification tap
  }
}
