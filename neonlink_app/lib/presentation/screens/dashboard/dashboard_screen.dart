import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/telemetry_provider.dart';
import '../../../providers/telemetry_history_provider.dart';
import '../../../providers/connection_provider.dart';
import '../../shared/widgets/circular_gauge.dart';
import '../../shared/widgets/status_indicator.dart';

enum DashboardMode { circularGauges, compact, graph, gaming }

enum GraphMetric { cpu, gpu, ram, cpuTemp, gpuTemp }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardMode _currentMode = DashboardMode.circularGauges;
  GraphMetric _selectedMetric = GraphMetric.cpu;

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider);
    final connectionState = ref.watch(connectionProvider);
    final history = ref.watch(telemetryHistoryProvider);

    // Обновляем историю при получении новых данных
    if (telemetry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(telemetryHistoryProvider.notifier).addData(telemetry);
      });
    }

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
              onPressed: () {
                ref.read(appRouterProvider).goNamed('settings');
              },
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
            child: _buildContent(telemetry, history),
          ),
        ],
      ),
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

  Widget _buildContent(telemetry, List history) {
    switch (_currentMode) {
      case DashboardMode.circularGauges:
        return _buildCircularGaugesMode(telemetry);
      case DashboardMode.compact:
        return _buildCompactMode(telemetry);
      case DashboardMode.graph:
        return _buildGraphMode(telemetry, history);
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
              _buildInfoRow('Name', telemetry?.system.cpu.name ?? 'Unknown'),
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.cpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.cpu.temp ?? 0)),
              _buildInfoRow('Cores', '${telemetry?.system.cpu.cores.length ?? 0}'),
              _buildInfoRow('Clock', formatClockSpeed(telemetry?.system.cpu.clock ?? 0)),
              if (telemetry?.system.cpu.power != null)
                _buildInfoRow('Power', '${telemetry!.system.cpu.power!.toStringAsFixed(1)} W'),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'GPU',
            [
              _buildInfoRow('Name', telemetry?.system.gpu.name ?? 'Unknown'),
              _buildInfoRow('Type', telemetry?.system.gpu.type ?? 'Unknown'),
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.gpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.gpu.temp ?? 0)),
              _buildInfoRow('VRAM Used', '${(telemetry?.system.gpu.vramUsed ?? 0).toStringAsFixed(1)} GB'),
              _buildInfoRow('VRAM Total', '${(telemetry?.system.gpu.vramTotal ?? 0).toStringAsFixed(1)} GB'),
              _buildInfoRow('Clock', formatClockSpeed(telemetry?.system.gpu.clock ?? 0)),
              if (telemetry?.system.gpu.fanSpeed != null)
                _buildInfoRow('Fan Speed', '${telemetry!.system.gpu.fanSpeed} RPM'),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'RAM',
            [
              _buildInfoRow('Used', '${(telemetry?.system.ram.used ?? 0).toStringAsFixed(1)} GB'),
              _buildInfoRow('Total', '${(telemetry?.system.ram.total ?? 0).toStringAsFixed(1)} GB'),
              _buildInfoRow('Available', '${(telemetry?.system.ram.available ?? 0).toStringAsFixed(1)} GB'),
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.ram.usedPercent ?? 0)),
              if (telemetry?.system.ram.speed != null)
                _buildInfoRow('Speed', '${telemetry!.system.ram.speed} MHz'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Storage Cards
          if (telemetry?.system.storage.isNotEmpty == true)
            ...telemetry!.system.storage.map((storage) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildInfoCard(
                  'Storage: ${storage.name}',
                  [
                    if (storage.temp != null)
                      _buildInfoRow('Temperature', formatTemperature(storage.temp!)),
                    if (storage.health != null)
                      _buildInfoRow('Health', '${storage.health}%'),
                    if (storage.smart != null) ...[
                      if (storage.smart!.tbw != null)
                        _buildInfoRow('TBW', '${storage.smart!.tbw} TB'),
                      if (storage.smart!.powerOnHours != null)
                        _buildInfoRow('Power On', '${storage.smart!.powerOnHours} h'),
                    ],
                  ],
                ),
              ),
            ),
          
          _buildInfoCard(
            'Network',
            [
              _buildInfoRow('Download', formatNetworkSpeed(telemetry?.system.network?.download ?? 0)),
              _buildInfoRow('Upload', formatNetworkSpeed(telemetry?.system.network?.upload ?? 0)),
              _buildInfoRow('Ping', '${telemetry?.system.network?.ping ?? 0} ms'),
              _buildInfoRow('IP', telemetry?.system.network?.ip ?? '--'),
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
        const SizedBox(height: 8),
        _buildCompactCard('CPU Temp', telemetry?.system.cpu.temp ?? 0, Colors.red, unit: '°C'),
      ],
    );
  }

  Widget _buildGraphMode(telemetry, List history) {
    // Если нет данных, показываем заглушку
    if (history.isEmpty) {
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
            const Text(
              'Graph Mode',
              style: TextStyle(
                color: NeonTheme.text,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for data...',
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    // Выбор метрики
    return Column(
      children: [
        // Metric selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: GraphMetric.values.map((metric) {
                final isSelected = metric == _selectedMetric;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getMetricName(metric)),
                    selected: isSelected,
                    selectedColor: _getMetricColor(metric),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedMetric = metric);
                      }
                    },
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Current value
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getMetricName(_selectedMetric),
                style: const TextStyle(
                  color: NeonTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getCurrentValue(telemetry, _selectedMetric),
                style: TextStyle(
                  color: _getMetricColor(_selectedMetric),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildChart(history, _selectedMetric),
          ),
        ),

        // Stats
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildStats(history, _selectedMetric),
        ),
      ],
    );
  }

  Widget _buildChart(List history, GraphMetric metric) {
    final data = _getMetricData(history, metric);
    if (data.isEmpty) return const SizedBox();

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getMetricInterval(metric),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: _getMetricMax(metric),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _getMetricColor(metric),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _getMetricColor(metric).withValues(alpha: 0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => NeonTheme.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)}%',
                  TextStyle(color: _getMetricColor(metric)),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStats(List history, GraphMetric metric) {
    final data = _getMetricData(history, metric);
    if (data.isEmpty) return const SizedBox();

    final avg = data.reduce((a, b) => a + b) / data.length;
    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);

    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Avg', '${avg.toStringAsFixed(1)}%', Colors.grey),
            _buildStatItem('Max', '${max.toStringAsFixed(1)}%', Colors.red),
            _buildStatItem('Min', '${min.toStringAsFixed(1)}%', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getMetricName(GraphMetric metric) {
    switch (metric) {
      case GraphMetric.cpu:
        return 'CPU';
      case GraphMetric.gpu:
        return 'GPU';
      case GraphMetric.ram:
        return 'RAM';
      case GraphMetric.cpuTemp:
        return 'CPU Temp';
      case GraphMetric.gpuTemp:
        return 'GPU Temp';
    }
  }

  Color _getMetricColor(GraphMetric metric) {
    switch (metric) {
      case GraphMetric.cpu:
        return NeonTheme.primary;
      case GraphMetric.gpu:
        return NeonTheme.secondary;
      case GraphMetric.ram:
        return NeonTheme.accent;
      case GraphMetric.cpuTemp:
        return Colors.orange;
      case GraphMetric.gpuTemp:
        return Colors.red;
    }
  }

  String _getCurrentValue(telemetry, GraphMetric metric) {
    switch (metric) {
      case GraphMetric.cpu:
        return '${(telemetry?.system.cpu.usage ?? 0).toStringAsFixed(1)}%';
      case GraphMetric.gpu:
        return '${(telemetry?.system.gpu.usage ?? 0).toStringAsFixed(1)}%';
      case GraphMetric.ram:
        return '${(telemetry?.system.ram.usedPercent ?? 0).toStringAsFixed(1)}%';
      case GraphMetric.cpuTemp:
        return '${(telemetry?.system.cpu.temp ?? 0).toStringAsFixed(0)}°C';
      case GraphMetric.gpuTemp:
        return '${(telemetry?.system.gpu.temp ?? 0).toStringAsFixed(0)}°C';
    }
  }

  List<double> _getMetricData(List history, GraphMetric metric) {
    switch (metric) {
      case GraphMetric.cpu:
        return history.map((e) => e.system.cpu.usage as double).toList();
      case GraphMetric.gpu:
        return history.map((e) => e.system.gpu.usage as double).toList();
      case GraphMetric.ram:
        return history.map((e) => e.system.ram.usedPercent as double).toList();
      case GraphMetric.cpuTemp:
        return history.map((e) => e.system.cpu.temp as double).toList();
      case GraphMetric.gpuTemp:
        return history.map((e) => e.system.gpu.temp as double).toList();
    }
  }

  double _getMetricMax(GraphMetric metric) {
    switch (metric) {
      case GraphMetric.cpu:
      case GraphMetric.gpu:
      case GraphMetric.ram:
        return 100;
      case GraphMetric.cpuTemp:
      case GraphMetric.gpuTemp:
        return 100;
    }
  }

  double _getMetricInterval(GraphMetric metric) {
    switch (metric) {
      case GraphMetric.cpu:
      case GraphMetric.gpu:
      case GraphMetric.ram:
        return 25;
      case GraphMetric.cpuTemp:
      case GraphMetric.gpuTemp:
        return 20;
    }
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
              _buildGamingStat('1% Low', formatFPS(gaming?.fps1Low), NeonTheme.warning),
              _buildGamingStat('Frame Time', formatFrameTime(gaming?.frametime), NeonTheme.accent),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'GPU Metrics',
            [
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.gpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.gpu.temp ?? 0)),
              _buildInfoRow('VRAM Used', '${(telemetry?.system.gpu.vramUsed ?? 0).toStringAsFixed(1)} GB'),
              _buildInfoRow('VRAM Usage', formatPercentage(telemetry?.system.gpu.vramUsagePercent ?? 0)),
              if (telemetry?.system.gpu.power != null)
                _buildInfoRow('Power', '${telemetry!.system.gpu.power!.toStringAsFixed(1)} W'),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'CPU Metrics',
            [
              _buildInfoRow('Usage', formatPercentage(telemetry?.system.cpu.usage ?? 0)),
              _buildInfoRow('Temperature', formatTemperature(telemetry?.system.cpu.temp ?? 0)),
              _buildInfoRow('Clock', formatClockSpeed(telemetry?.system.cpu.clock ?? 0)),
              if (telemetry?.system.cpu.power != null)
                _buildInfoRow('Power', '${telemetry!.system.cpu.power!.toStringAsFixed(1)} W'),
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
}
