import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

Future<void> configureLocalTimezone() async {
  final localTimezone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTimezone));
}
