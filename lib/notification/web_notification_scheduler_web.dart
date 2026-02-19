export 'web_notification_scheduler_stub.dart';

import 'dart:async';
import 'dart:html' as html;

import 'web_notification_scheduler_stub.dart';

class WebNotificationSchedulerImpl extends WebNotificationScheduler {
  final Map<int, Timer> _timers = {};

  @override
  Future<void> requestPermission() async {
    if (!html.Notification.supported) {
      return;
    }
    if (html.Notification.permission == 'default') {
      await html.Notification.requestPermission();
    }
  }

  @override
  void schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) {
    if (!html.Notification.supported || html.Notification.permission != 'granted') {
      return;
    }

    final delay = when.difference(DateTime.now());
    if (delay.isNegative) {
      return;
    }

    _timers[id]?.cancel();
    _timers[id] = Timer(delay, () {
      html.Notification(title, body: body);
      _timers.remove(id);
    });
  }

  @override
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

WebNotificationScheduler createWebNotificationScheduler() =>
    WebNotificationSchedulerImpl();
