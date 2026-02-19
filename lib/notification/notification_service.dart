import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:chronosense/core/algorithm/interval_engine.dart';
import 'package:chronosense/domain/model/models.dart';
import 'package:chronosense/util/time_utils.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'web_notification_scheduler_stub.dart'
    if (dart.library.html) 'web_notification_scheduler_web.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _webScheduler = createWebNotificationScheduler();

  static const _channelId = 'chronosense_interval';
  static const _channelName = 'Interval Reminders';
  static const _channelDesc = 'Notifications at each check-in interval';

  var _tzInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

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

    _initializeTimezone();
  }

  Future<void> requestPermission() async {
    if (kIsWeb) {
      await _webScheduler.requestPermission();
      return;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleForToday(UserPreferences prefs) async {
    await cancelAll();

    if (!prefs.notificationsEnabled) {
      return;
    }

    final now = DateTime.now();
    final boundaries = IntervalEngine.remainingBoundaries(
      prefs: prefs,
      now: now,
    );

    for (int i = 0; i < boundaries.length && i < 24; i++) {
      final boundary = boundaries[i];
      if (boundary.isBefore(now)) continue;

      final endMin = boundary.hour * 60 + boundary.minute;
      final startMin = endMin - prefs.intervalMinutes;
      final startTime =
          '${(startMin ~/ 60).toString().padLeft(2, '0')}:${(startMin % 60).toString().padLeft(2, '0')}';
      final endTime =
          '${boundary.hour.toString().padLeft(2, '0')}:${boundary.minute.toString().padLeft(2, '0')}';

      final body = 'How was ${TimeUtils.formatTimeRange(startTime, endTime)}?';

      if (kIsWeb) {
        _webScheduler.schedule(
          id: i,
          when: boundary,
          title: 'Time to reflect ✨',
          body: body,
        );
      } else {
        await _plugin.zonedSchedule(
          id: i,
          title: 'Time to reflect ✨',
          body: body,
          scheduledDate: tz.TZDateTime.from(boundary, tz.local),
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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> scheduleFromPreferences(UserPreferences prefs) async {
    if (prefs.notificationsEnabled) {
      await requestPermission();
      await scheduleForToday(prefs);
    } else {
      await cancelAll();
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      _webScheduler.cancelAll();
      return;
    }
    await _plugin.cancelAll();
  }

  void _initializeTimezone() {
    if (_tzInitialized) {
      return;
    }
    tz.initializeTimeZones();
    _tzInitialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {}
}
