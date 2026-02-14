import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/connection/connection_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/control/control_screen.dart';
import '../screens/themes/theme_store_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/logs/logs_screen.dart';
import '../screens/scripts/scripts_screen.dart';
import '../screens/about/about_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/connection',
    routes: [
      GoRoute(
        path: '/connection',
        name: 'connection',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/control',
        name: 'control',
        builder: (context, state) => const ControlScreen(),
      ),
      GoRoute(
        path: '/themes',
        name: 'themes',
        builder: (context, state) => const ThemeStoreScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/logs',
        name: 'logs',
        builder: (context, state) => const LogsScreen(),
      ),
      GoRoute(
        path: '/scripts',
        name: 'scripts',
        builder: (context, state) => const ScriptsScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
    ],
    errorBuilder: (context, state) => const ConnectionScreen(),
  );
});
