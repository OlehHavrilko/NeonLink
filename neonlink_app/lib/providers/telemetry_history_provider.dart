import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/telemetry_data.dart';

/// История точек данных для графиков
class TelemetryHistoryNotifier extends Notifier<List<TelemetryData>> {
  static const int maxHistoryLength = 60; // 60 точек данных (примерно 1 минута при 1 обновлении в секунду)

  @override
  List<TelemetryData> build() => [];

  /// Добавить новую точку данных
  void addData(TelemetryData data) {
    final newList = [...state, data];
    
    // Ограничить длину истории
    if (newList.length > maxHistoryLength) {
      newList.removeRange(0, newList.length - maxHistoryLength);
    }
    
    state = newList;
  }

  /// Очистить историю
  void clear() {
    state = [];
  }

  /// Получить последние N точек
  List<TelemetryData> getLastN(int n) {
    if (state.length <= n) return state;
    return state.sublist(state.length - n);
  }

  // Получить историю CPU
  List<double> get cpuHistory => state.map((e) => e.system.cpu.usage).toList();

  // Получить историю GPU
  List<double> get gpuHistory => state.map((e) => e.system.gpu.usage).toList();

  // Получить историю RAM
  List<double> get ramHistory => state.map((e) => e.system.ram.usedPercent).toList();

  // Получить историю температуры CPU
  List<double> get cpuTempHistory => state.map((e) => e.system.cpu.temp).toList();

  // Получить историю температуры GPU
  List<double> get gpuTempHistory => state.map((e) => e.system.gpu.temp).toList();
}

final telemetryHistoryProvider = NotifierProvider<TelemetryHistoryNotifier, List<TelemetryData>>(
  TelemetryHistoryNotifier.new,
);
