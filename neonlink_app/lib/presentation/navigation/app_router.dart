import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/connection/connection_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/control/control_screen.dart';
import '../screens/themes/theme_store_screen.dart';
import '../screens/settings/settings_screen.dart';

final appRouter = GoRouter(
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
  ],
);
