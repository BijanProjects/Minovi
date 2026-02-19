import 'package:timezone/timezone.dart' as tz;

Future<void> configureLocalTimezone() async {
  tz.setLocalLocation(tz.getLocation('UTC'));
}
