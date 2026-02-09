import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/telemetry_provider.dart';
import '../../../providers/connection_provider.dart';
import '../../shared/widgets/circular_gauge.dart';
import '../../shared/widgets/status_indicator.dart';

enum DashboardMode { circularGauges, compact, graph, gaming }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardMode _currentMode = DashboardMode.circularGauges;

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider);
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      backgroundColor: NeonTheme.background,
      appBar: AppBar(
        backgroundColor: NeonTheme.surface,
        title: Row(
          children: [
            StatusIndicator(
              level: connectionState.isConnected 
                  ? StatusLevel.safe 
                  : StatusLevel.disconnected,
              label: connectionState.isConnected ? 'Connected' : 'Disconnected',
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings, color: NeonTheme.primary),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mode Selector
          _buildModeSelector(),
          
          // Content
          Expanded(
            child: _buildContent(telemetry),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: DashboardMode.values.map((mode) {
          final isSelected = mode == _currentMode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text(mode.name),
              selectedColor: NeonTheme.primary,
              backgroundColor: NeonTheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : NeonTheme.primary,
              ),
              onSelected: (selected) {
                setState(() => _currentMode = mode);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent(telemetry) {
    switch (_currentMode) {
      case DashboardMode.circularGauges:
        return _buildCircularGaugesMode(telemetry);
      case DashboardMode.compact:
        return _buildCompactMode(telemetry);
      case DashboardMode.graph:
        return _buildGraphMode(telemetry);
      case DashboardMode.gaming:
        return _buildGamingMode(telemetry);
    }
  }

  Widget _buildCircularGaugesMode(telemetry) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // CPU & GPU Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularGauge(
                value: telemetry?.system.cpu.usage ?? 0,
                label: 'CPU',
                unit: '%',
                size: 140,
              ),
              CircularGauge(
                value: telemetry?.system.gpu.usage ?? 0,
                label: 'GPU',
                unit: '%',
                size: 140,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // RAM & Temperature Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularGauge(
                value: telemetry?.system.ram.usedPercent ?? 0,
                label: 'RAM',
                unit: '%',
                size: 140,
              ),
              CircularGauge(
                value: telemetry?.system.gpu.temp ?? 0,
                label: 'GPU Temp',
                unit: '°C',
                max: 100,
                size: 140,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Detailed Info Cards
          _buildInfoCard(
            'CPU',
            [
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.cpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.cpu.temp ?? 0)),
              _buildInfoRow('Cores', '${telemetry?.system.cpu.cores ?? 0}'),
              _buildInfoRow('Clock', formatClockSpeed(telemetry?.system.cpu.clockSpeed ?? 0)),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'GPU',
            [
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.gpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.gpu.temp ?? 0)),
              _buildInfoRow('Memory', '${telemetry?.system.gpu.memory ?? 0} MB'),
              _buildInfoRow('VRAM', '${telemetry?.system.gpu.vram ?? 0} MB'),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Network',
            [
              _buildInfoRow('Download', formatNetworkSpeed(telemetry?.system.network.downloadSpeed ?? 0)),
              _buildInfoRow('Upload', formatNetworkSpeed(telemetry?.system.network.uploadSpeed ?? 0)),
              _buildInfoRow('IP', telemetry?.system.network.ip ?? '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMode(telemetry) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCompactCard('CPU', telemetry?.system.cpu.usage ?? 0, NeonTheme.primary),
        const SizedBox(height: 8),
        _buildCompactCard('GPU', telemetry?.system.gpu.usage ?? 0, NeonTheme.secondary),
        const SizedBox(height: 8),
        _buildCompactCard('RAM', telemetry?.system.ram.usedPercent ?? 0, NeonTheme.accent),
        const SizedBox(height: 8),
        _buildCompactCard('GPU Temp', telemetry?.system.gpu.temp ?? 0, Colors.orange, unit: '°C'),
      ],
    );
  }

  Widget _buildGraphMode(telemetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: NeonTheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Graph Mode',
            style: TextStyle(
              color: NeonTheme.text,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time charts coming soon',
            style: TextStyle(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamingMode(telemetry) {
    final gaming = telemetry?.gaming;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (gaming?.active == true) ...[
            Card(
              color: NeonTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.sports_esports,
                      size: 48,
                      color: NeonTheme.secondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gaming?.activeProcess ?? 'Game',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGamingStat('FPS', formatFPS(gaming?.fps), NeonTheme.safe),
              _buildGamingStat('Frame Time', formatFrameTime(gaming?.frameTime), NeonTheme.warning),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'GPU Metrics',
            [
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.gpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.gpu.temp ?? 0)),
              _buildInfoRow('VRAM', '${telemetry?.system.gpu.vram ?? 0} MB'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> rows) {
    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: NeonTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard(String label, double value, Color color, {String unit = '%'}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamingStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.gamepad, 'label': 'Control'},
      {'icon': Icons.palette, 'label': 'Themes'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: NeonTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == 0; // Dashboard is selected by default
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  item['icon'] as IconData,
                  color: isSelected ? NeonTheme.primary : Colors.grey,
                ),
                onPressed: () {},
              ),
              Text(
                item['label'] as String,
                style: TextStyle(
                  color: isSelected ? NeonTheme.primary : Colors.grey,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
            ],
          );
        }).toList(),
      ),
    );
  }
}
