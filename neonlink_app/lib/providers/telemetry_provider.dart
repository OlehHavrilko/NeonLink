import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/telemetry_data.dart';
import '../core/constants/app_constants.dart';

class TelemetryNotifier extends Notifier<TelemetryData?> {
  TelemetryData? _lastData;

  @override
  TelemetryData? build() => null;

  void updateData(TelemetryData newData) {
    // Throttle: обновлять UI только если изменение > 1%
    if (_lastData != null) {
      final cpuDiff = (newData.system.cpu.usage - _lastData!.system.cpu.usage).abs();
      if (cpuDiff < AppConstants.updateThrottleThreshold) {
        return; // Skip UI update
      }
    }

    _lastData = newData;
    state = newData;
  }

  // Computed values
  double get cpuUsage => state?.system.cpu.usage ?? 0;
  double get gpuUsage => state?.system.gpu.usage ?? 0;
  double get ramUsage => state?.system.ram.usedPercent ?? 0;
  double get gpuTemp => state?.system.gpu.temp ?? 0;
  double get cpuTemp => state?.system.cpu.temp ?? 0;
  int? get fps => state?.gaming?.fps;
  bool get isGaming => state?.gaming?.active ?? false;
}

final telemetryProvider = NotifierProvider<TelemetryNotifier, TelemetryData?>(
  TelemetryNotifier.new,
);
