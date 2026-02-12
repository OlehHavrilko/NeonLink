import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/telemetry_data.dart';
import '../core/constants/app_constants.dart';

/// Notifier для управления состоянием телеметрии
class TelemetryNotifier extends Notifier<TelemetryData?> {
  TelemetryData? _lastData;

  @override
  TelemetryData? build() => null;

  /// Обновление данных телеметрии с throttling
  void updateData(TelemetryData newData) {
    // Throttle: обновлять UI только если изменение > порога
    if (_lastData != null) {
      final cpuDiff = (newData.system.cpu.usage - _lastData!.system.cpu.usage).abs();
      final gpuDiff = (newData.system.gpu.usage - _lastData!.system.gpu.usage).abs();
      
      if (cpuDiff < AppConstants.updateThrottleThreshold && 
          gpuDiff < AppConstants.updateThrottleThreshold) {
        return; // Skip UI update
      }
    }

    _lastData = newData;
    state = newData;
  }

  /// Сброс состояния
  void reset() {
    _lastData = null;
    state = null;
  }

  // ============ CPU ============
  
  double get cpuUsage => state?.system.cpu.usage ?? 0;
  double get cpuTemp => state?.system.cpu.temp ?? 0;
  double get cpuClock => state?.system.cpu.clock ?? 0;
  double? get cpuPower => state?.system.cpu.power;
  String get cpuName => state?.system.cpu.name ?? '';
  List<CpuCoreInfo> get cpuCores => state?.system.cpu.cores ?? [];

  // ============ GPU ============
  
  double get gpuUsage => state?.system.gpu.usage ?? 0;
  double get gpuTemp => state?.system.gpu.temp ?? 0;
  double get gpuClock => state?.system.gpu.clock ?? 0;
  double? get gpuMemoryClock => state?.system.gpu.memoryClock;
  double? get gpuPower => state?.system.gpu.power;
  int? get gpuFanSpeed => state?.system.gpu.fanSpeed;
  String get gpuName => state?.system.gpu.name ?? '';
  String get gpuType => state?.system.gpu.type ?? '';
  double get gpuVramUsed => state?.system.gpu.vramUsed ?? 0;
  double get gpuVramTotal => state?.system.gpu.vramTotal ?? 0;
  double get gpuVramUsagePercent => state?.system.gpu.vramUsagePercent ?? 0;

  // ============ RAM ============
  
  double get ramUsed => state?.system.ram.used ?? 0;
  double get ramTotal => state?.system.ram.total ?? 0;
  double get ramAvailable => state?.system.ram.available ?? 0;
  double get ramUsagePercent => state?.system.ram.usedPercent ?? 0;
  int? get ramSpeed => state?.system.ram.speed;

  // ============ Storage ============
  
  List<StorageInfo> get storageList => state?.system.storage ?? [];
  int get storageCount => state?.system.storage.length ?? 0;
  
  /// Получить первый накопитель (основной)
  StorageInfo? get primaryStorage => 
      state?.system.storage.isNotEmpty == true 
          ? state!.system.storage.first 
          : null;

  // ============ Network ============
  
  double get networkDownload => state?.system.network?.download ?? 0;
  double get networkUpload => state?.system.network?.upload ?? 0;
  int get networkPing => state?.system.network?.ping ?? 0;
  String? get networkIp => state?.system.network?.ip;

  // ============ Gaming ============
  
  bool get isGaming => state?.gaming?.active ?? false;
  int? get fps => state?.gaming?.fps;
  int? get fps1Low => state?.gaming?.fps1Low;
  double? get frametime => state?.gaming?.frametime;
  String? get activeProcess => state?.gaming?.activeProcess;

  // ============ System ============
  
  String get adminLevel => state?.adminLevel ?? 'Unknown';
  int get timestamp => state?.timestamp ?? 0;
  
  /// Проверка наличия данных
  bool get hasData => state != null;
}

final telemetryProvider = NotifierProvider<TelemetryNotifier, TelemetryData?>(
  TelemetryNotifier.new,
);
