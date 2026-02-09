class TemperatureUnit {
  static const celsius = '°C';
  static const fahrenheit = '°F';
  static const kelvin = 'K';
}

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

String formatBytes(double megabytes) {
  if (megabytes >= 1024) {
    return '${(megabytes / 1024).toStringAsFixed(2)} GB';
  }
  return '${megabytes.toStringAsFixed(1)} MB';
}

String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '$bytesPerSecond B/s';
}

String formatPercentage(double value) {
  return '${value.toStringAsFixed(1)}%';
}

String formatFrequency(double mhz) {
  if (mhz >= 1000) {
    return '${(mhz / 1000).toStringAsFixed(2)} GHz';
  }
  return '${mhz.toStringAsFixed(0)} MHz';
}

String formatClockSpeed(double ghz) {
  return '${ghz.toStringAsFixed(2)} GHz';
}

String formatNetworkSpeed(int bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '$bytesPerSecond B/s';
}

String formatFPS(int? fps) {
  if (fps == null) return '--';
  return '$fps FPS';
}

String formatFrameTime(int? frameTime) {
  if (frameTime == null) return '--';
  return '${frameTime}ms';
}
