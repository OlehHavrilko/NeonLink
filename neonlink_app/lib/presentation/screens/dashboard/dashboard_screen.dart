import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../services/websocket_service.dart';
import '../control/control_screen.dart';
import '../themes/theme_store_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardContent(),
    const ControlScreen(),
    const ThemeStoreScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonTheme.background,
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            backgroundColor: NeonTheme.surface,
            indicatorColor: NeonTheme.primary.withOpacity(0.2),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard, color: NeonTheme.text),
                label: Text('Dashboard', style: TextStyle(color: NeonTheme.text)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings, color: NeonTheme.text),
                label: Text('Control', style: TextStyle(color: NeonTheme.text)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.palette, color: NeonTheme.text),
                label: Text('Themes', style: TextStyle(color: NeonTheme.text)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune, color: NeonTheme.text),
                label: Text('Settings', style: TextStyle(color: NeonTheme.text)),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: NeonTheme.primary),
          // Main Content
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}

class DashboardContent extends ConsumerWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryData = ref.watch(telemetryProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);

    return StreamBuilder<ConnectionStatus>(
      stream: ref.read(webSocketServiceProvider).statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? connectionStatus;
        
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SYSTEM MONITOR',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 24,
                      color: NeonTheme.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == ConnectionStatus.connected 
                          ? NeonTheme.safe.withOpacity(0.2)
                          : NeonTheme.critical.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: status == ConnectionStatus.connected 
                            ? NeonTheme.safe 
                            : NeonTheme.critical,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == ConnectionStatus.connected 
                              ? Icons.wifi 
                              : Icons.wifi_off,
                          size: 16,
                          color: status == ConnectionStatus.connected 
                              ? NeonTheme.safe 
                              : NeonTheme.critical,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == ConnectionStatus.connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            color: status == ConnectionStatus.connected 
                                ? NeonTheme.safe 
                                : NeonTheme.critical,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Metrics Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMetricCard(
                      icon: Icons.memory,
                      title: 'CPU',
                      value: '${telemetryData?.system.cpu.usage.toStringAsFixed(0) ?? '0'}%',
                      subtitle: '${telemetryData?.system.cpu.temp.toStringAsFixed(0) ?? '0'}°C',
                      progress: (telemetryData?.system.cpu.usage ?? 0) / 100,
                      color: _getUsageColor(telemetryData?.system.cpu.usage ?? 0),
                    ),
                    _buildMetricCard(
                      icon: Icons.speed,
                      title: 'GPU',
                      value: '${telemetryData?.system.gpu.usage.toStringAsFixed(0) ?? '0'}%',
                      subtitle: '${telemetryData?.system.gpu.temp.toStringAsFixed(0) ?? '0'}°C',
                      progress: (telemetryData?.system.gpu.usage ?? 0) / 100,
                      color: _getUsageColor(telemetryData?.system.gpu.usage ?? 0),
                    ),
                    _buildMetricCard(
                      icon: Icons.storage,
                      title: 'RAM',
                      value: '${telemetryData?.system.ram.usedPercent.toStringAsFixed(0) ?? '0'}%',
                      subtitle: '${telemetryData?.system.ram.usedGb.toStringAsFixed(1)} / ${telemetryData?.system.ram.totalGb.toStringAsFixed(1)} GB',
                      progress: (telemetryData?.system.ram.usedPercent ?? 0) / 100,
                      color: _getUsageColor(telemetryData?.system.ram.usedPercent ?? 0),
                    ),
                    _buildMetricCard(
                      icon: Icons.hard_drive,
                      title: 'STORAGE',
                      value: '${telemetryData?.system.storage.usedPercent.toStringAsFixed(0) ?? '0'}%',
                      subtitle: '${telemetryData?.system.storage.readSpeed ?? 0} / ${telemetryData?.system.storage.writeSpeed ?? 0} MB/s',
                      progress: (telemetryData?.system.storage.usedPercent ?? 0) / 100,
                      color: _getUsageColor(telemetryData?.system.storage.usedPercent ?? 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getUsageColor(double usage) {
    if (usage < 50) return NeonTheme.safe;
    if (usage < 80) return NeonTheme.warning;
    return NeonTheme.critical;
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required double progress,
    required Color color,
  }) {
    return Card(
      color: NeonTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    color: NeonTheme.text,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: NeonTheme.text.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Providers
final telemetryProvider = StateProvider<TelemetryData?>((ref) => null);
final connectionStatusProvider = StateProvider<ConnectionStatus>((ref) => ConnectionStatus.disconnected);
final webSocketServiceProvider = Provider<WebSocketService>((ref) => WebSocketService());
