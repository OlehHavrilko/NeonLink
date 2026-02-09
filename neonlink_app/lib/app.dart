import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/neon_theme.dart';
import 'presentation/screens/connection/connection_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/themes/theme_store_screen.dart';
import 'presentation/screens/control/control_screen.dart';

class NeonLinkApp extends ConsumerWidget {
  const NeonLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NeonLink',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ConnectionScreen(),
    const DashboardScreen(),
    const ControlScreen(),
    const ThemeStoreScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonTheme.background,
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: NeonTheme.surface,
        indicatorColor: NeonTheme.primary.withValues(alpha: 0.3),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wifi, color: Colors.grey),
            selectedIcon: Icon(Icons.wifi, color: NeonTheme.primary),
            label: 'Connect',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard, color: Colors.grey),
            selectedIcon: Icon(Icons.dashboard, color: NeonTheme.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.gamepad, color: Colors.grey),
            selectedIcon: Icon(Icons.gamepad, color: NeonTheme.primary),
            label: 'Control',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette, color: Colors.grey),
            selectedIcon: Icon(Icons.palette, color: NeonTheme.primary),
            label: 'Themes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings, color: Colors.grey),
            selectedIcon: Icon(Icons.settings, color: NeonTheme.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
