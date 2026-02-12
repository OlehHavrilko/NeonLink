/// Единицы измерения температуры
class TemperatureUnit {
  static const celsius = '°C';
  static const fahrenheit = '°F';
  static const kelvin = 'K';
}

/// Форматирование температуры
String formatTemperature(double celsius, [String unit = TemperatureUnit.celsius]) {
  switch (unit) {
    case TemperatureUnit.fahrenheit:
      return '${(celsius * 9 / 5 + 32).toStringAsFixed(1)}°F';
    case TemperatureUnit.kelvin:
      return '${(celsius + 273.15).toStringAsFixed(1)}K';
    default:
      return '${celsius.toStringAsFixed(1)}°C';
  }
}

/// Форматирование байтов (MB -> MB/GB)
String formatBytes(double megabytes) {
  if (megabytes >= 1024) {
    return '${(megabytes / 1024).toStringAsFixed(2)} GB';
  }
  return '${megabytes.toStringAsFixed(1)} MB';
}

/// Форматирование гигабайтов
String formatGigabytes(double gigabytes) {
  if (gigabytes >= 1024) {
    return '${(gigabytes / 1024).toStringAsFixed(2)} TB';
  }
  return '${gigabytes.toStringAsFixed(1)} GB';
}

/// Форматирование скорости в байтах/сек
String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '$bytesPerSecond B/s';
}

/// Форматирование процента
String formatPercentage(double value) {
  return '${value.toStringAsFixed(1)}%';
}

/// Форматирование частоты (MHz -> MHz/GHz)
String formatFrequency(double mhz) {
  if (mhz >= 1000) {
    return '${(mhz / 1000).toStringAsFixed(2)} GHz';
  }
  return '${mhz.toStringAsFixed(0)} MHz';
}

/// Форматирование тактовой частоты (GHz)
String formatClockSpeed(double ghz) {
  if (ghz >= 1000) {
    // Если значение в MHz
    return '${(ghz / 1000).toStringAsFixed(2)} GHz';
  }
  return '${ghz.toStringAsFixed(2)} GHz';
}

/// Форматирование сетевой скорости (Gbps от сервера)
String formatNetworkSpeed(double gbps) {
  if (gbps >= 1) {
    return '${gbps.toStringAsFixed(2)} Gbps';
  }
  // Конвертируем в Mbps
  final mbps = gbps * 1000;
  if (mbps >= 1) {
    return '${mbps.toStringAsFixed(1)} Mbps';
  }
  return '${(mbps * 1000).toStringAsFixed(0)} Kbps';
}

/// Форматирование FPS
String formatFPS(int? fps) {
  if (fps == null) return '--';
  return '$fps FPS';
}

/// Форматирование времени кадра (ms)
String formatFrameTime(double? frameTime) {
  if (frameTime == null) return '--';
  return '${frameTime.toStringAsFixed(1)}ms';
}

/// Форматирование мощности (W)
String formatPower(double? watts) {
  if (watts == null) return '--';
  return '${watts.toStringAsFixed(1)} W';
}

/// Форматирование скорости вентилятора (RPM)
String formatFanSpeed(int? rpm) {
  if (rpm == null) return '--';
  return '$rpm RPM';
}

/// Форматирование пинга (ms)
String formatPing(int ping) {
  if (ping < 0) return '--';
  return '${ping}ms';
}

/// Форматирование аптайма (секунды -> читаемый формат)
String formatUptime(int seconds) {
  if (seconds < 60) {
    return '${seconds}s';
  } else if (seconds < 3600) {
    final minutes = seconds ~/ 60;
    return '${minutes}m';
  } else if (seconds < 86400) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  } else {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    return '${days}d ${hours}h';
  }
}

/// Форматирование timestamp (Unix timestamp -> время)
String formatTimestamp(int timestamp) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return '${dateTime.hour.toString().padLeft(2, '0')}:'
         '${dateTime.minute.toString().padLeft(2, '0')}:'
         '${dateTime.second.toString().padLeft(2, '0')}';
}
