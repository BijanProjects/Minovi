import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chronosense/ui/screens/day/day_screen.dart';
import 'package:chronosense/ui/screens/day/day_provider.dart';
import 'package:chronosense/ui/screens/entry/entry_screen.dart';
import 'package:chronosense/ui/screens/month/month_screen.dart';
import 'package:chronosense/ui/screens/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/day',
    routes: [
      // ── Shell route for bottom nav ──
      ShellRoute(
        builder: (context, state, child) {
          return _AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/day',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: Consumer(
                builder: (context, ref, _) => DayScreen(
                  onSlotTap: (date, start, end) {
                    context.push('/entry/$date/$start/$end');
                  },
                ),
              ),
              transitionsBuilder: _fadeThrough,
            ),
          ),
          GoRoute(
            path: '/month',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: Consumer(
                builder: (context, ref, _) => MonthScreen(
                  onDayTap: (date) {
                    ref.read(dayProvider.notifier).goToDate(date);
                    context.go('/day');
                  },
                ),
              ),
              transitionsBuilder: _fadeThrough,
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder: _fadeThrough,
            ),
          ),
        ],
      ),

      // ── Entry route (outside shell — no bottom nav) ──
      GoRoute(
        path: '/entry/:date/:startTime/:endTime',
        pageBuilder: (context, state) {
          final date = state.pathParameters['date']!;
          final startTime = state.pathParameters['startTime']!;
          final endTime = state.pathParameters['endTime']!;

          return CustomTransitionPage(
            key: state.pageKey,
            child: Consumer(
              builder: (context, ref, _) => EntryScreen(
                date: date,
                startTime: startTime,
                endTime: endTime,
                onBack: () {
                  ref.read(dayProvider.notifier).refresh();
                  context.pop();
                },
              ),
            ),
            transitionsBuilder: _sharedAxisVertical,
          );
        },
      ),
    ],
  );
});

// ── Tab transition: Fade + Horizontal Slide (matching Kotlin) ──
Widget _fadeThrough(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.03, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      )),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
          ),
        ),
        child: child,
      ),
    ),
  );
}

// ── Entry screen transition: Fade + Horizontal Slide (matching Kotlin) ──
Widget _sharedAxisVertical(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    )),
    child: FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
          ),
        ),
        child: child,
      ),
    ),
  );
}

// ── Bottom navigation shell ──
class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _tabs = [
    (path: '/day', label: 'Today', iconFilled: Icons.today, iconOutlined: Icons.today_outlined),
    (path: '/month', label: 'Month', iconFilled: Icons.calendar_month, iconOutlined: Icons.calendar_month_outlined),
    (path: '/settings', label: 'Settings', iconFilled: Icons.settings, iconOutlined: Icons.settings_outlined),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i != index) {
            GoRouter.of(context).go(_tabs[i].path);
          }
        },
        animationDuration: const Duration(milliseconds: 350),
        destinations: _tabs.map((tab) {
          final isSelected = _tabs.indexOf(tab) == index;
          return NavigationDestination(
            icon: Icon(
              isSelected ? tab.iconFilled : tab.iconOutlined,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}
