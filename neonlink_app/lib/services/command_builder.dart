import 'dart:convert';

/// Типизированный строитель команд для WebSocket протокола NeonLink
/// Версия API: 1.0.0
class CommandBuilder {
  CommandBuilder._();

  /// Проверка соединения (heartbeat)
  static String ping() => jsonEncode({
    'command': 'ping',
  });

  /// Получение статуса сервера
  static String getStatus() => jsonEncode({
    'command': 'get_status',
  });

  /// Запуск потока телеметрии
  static String getTelemetry() => jsonEncode({
    'command': 'get_telemetry',
  });

  /// Получение конфигурации сервера
  static String getConfig({String? section}) => jsonEncode({
    'command': 'get_config',
    if (section != null) 'params': {'section': section},
  });

  /// Установка интервала опроса сенсоров
  static String setPollingInterval(int intervalMs) => jsonEncode({
    'command': 'set_polling_interval',
    'params': {'intervalMs': intervalMs.clamp(100, 5000)},
  });

  /// Управление RGB подсветкой
  static String rgbEffect({
    required String effect,
    required String color,
    int? speed,
    int? brightness,
  }) => jsonEncode({
    'command': 'rgb_effect',
    'params': {
      'effect': effect,
      'color': color,
      if (speed != null) 'speed': speed.clamp(0, 100),
      if (brightness != null) 'brightness': brightness.clamp(0, 100),
    },
  });

  /// Управление скоростью вентиляторов
  static String setFanSpeed({
    required String profile,
    String? fan,
    int? speed,
  }) => jsonEncode({
    'command': 'set_fan_speed',
    'params': {
      'profile': profile,
      if (fan != null) 'fan': fan,
      if (speed != null) 'speed': speed.clamp(0, 100),
    },
  });

  /// Установка конфигурации
  static String setConfig({
    required String key,
    required dynamic value,
  }) => jsonEncode({
    'command': 'set_config',
    'params': {
      'key': key,
      'value': value,
    },
  });
}

/// Парсер ответов от сервера
class ResponseParser {
  ResponseParser._();

  /// Проверка успешности ответа
  static bool isSuccess(Map<String, dynamic> response) {
    return response['success'] == true;
  }

  /// Получение ошибки из ответа
  static String? getError(Map<String, dynamic> response) {
    return response['error'] as String?;
  }

  /// Получение результата из ответа
  static T? getResult<T>(Map<String, dynamic> response) {
    return response['result'] as T?;
  }

  /// Получение имени команды из ответа
  static String? getCommand(Map<String, dynamic> response) {
    return response['command'] as String?;
  }

  /// Получение timestamp из ответа
  static int? getTimestamp(Map<String, dynamic> response) {
    return response['timestamp'] as int?;
  }

  /// Проверка типа сообщения (телеметрия или ответ на команду)
  static bool isTelemetry(Map<String, dynamic> json) {
    // Телеметрия содержит timestamp и system, но не содержит success
    return json.containsKey('timestamp') && 
           json.containsKey('system') && 
           !json.containsKey('success');
  }

  /// Проверка ответа на команду
  static bool isCommandResponse(Map<String, dynamic> json) {
    return json.containsKey('success') && json.containsKey('command');
  }
}

/// Результат выполнения команды
class CommandResult<T> {
  final bool success;
  final T? result;
  final String? error;
  final String command;
  final int? timestamp;

  CommandResult({
    required this.success,
    this.result,
    this.error,
    required this.command,
    this.timestamp,
  });

  factory CommandResult.fromJson(Map<String, dynamic> json, T Function(dynamic)? parser) {
    return CommandResult<T>(
      success: json['success'] as bool? ?? false,
      result: parser != null && json['result'] != null 
          ? parser(json['result']) 
          : json['result'] as T?,
      error: json['error'] as String?,
      command: json['command'] as String? ?? '',
      timestamp: json['timestamp'] as int?,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'CommandResult.success(command: $command, result: $result)';
    }
    return 'CommandResult.error(command: $command, error: $error)';
  }
}

/// Модели ответов сервера

/// Ответ на команду ping
class PongResponse {
  final bool pong;
  final int timestamp;

  PongResponse({required this.pong, required this.timestamp});

  factory PongResponse.fromJson(Map<String, dynamic> json) {
    return PongResponse(
      pong: json['pong'] as bool? ?? false,
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}

/// Ответ на команду get_status
class StatusResponse {
  final bool connected;
  final int clientsConnected;
  final int uptime;
  final String adminLevel;
  final String version;

  StatusResponse({
    required this.connected,
    required this.clientsConnected,
    required this.uptime,
    required this.adminLevel,
    required this.version,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      connected: json['connected'] as bool? ?? false,
      clientsConnected: json['clientsConnected'] as int? ?? 0,
      uptime: json['uptime'] as int? ?? 0,
      adminLevel: json['adminLevel'] as String? ?? 'Unknown',
      version: json['version'] as String? ?? '0.0.0',
    );
  }
}

/// Ответ на команду set_polling_interval
class PollingIntervalResponse {
  final bool success;
  final int? intervalMs;
  final String? error;

  PollingIntervalResponse({
    required this.success,
    this.intervalMs,
    this.error,
  });

  factory PollingIntervalResponse.fromJson(Map<String, dynamic> json) {
    return PollingIntervalResponse(
      success: json['success'] as bool? ?? false,
      intervalMs: json['intervalMs'] as int?,
      error: json['error'] as String?,
    );
  }
}
