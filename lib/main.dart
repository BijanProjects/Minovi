import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/ui/theme/theme.dart';
import 'package:chronosense/ui/navigation/app_router.dart';
import 'package:chronosense/data/local/app_database.dart';
import 'package:chronosense/notification/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    await AppDatabase.instance.database;
    await NotificationService.instance.initialize();
  }

  runApp(const ProviderScope(child: ChronoSenseApp()));
}

class ChronoSenseApp extends ConsumerWidget {
  const ChronoSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ChronoSense',
      debugShowCheckedModeBanner: false,
      theme: ChronoTheme.light(),
      darkTheme: ChronoTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
