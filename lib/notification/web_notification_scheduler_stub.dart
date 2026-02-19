class WebNotificationScheduler {
  Future<void> requestPermission() async {}

  void schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) {}

  void cancelAll() {}
}

WebNotificationScheduler createWebNotificationScheduler() =>
    WebNotificationScheduler();
