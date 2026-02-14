/// Level of log entry
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Log entry model for local storage
class LogEntry {
  final int? id;
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final String? scriptId;
  final int? lineNumber;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.scriptId,
    this.lineNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'source': source,
      'message': message,
      'script_id': scriptId,
      'line_number': lineNumber,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      source: json['source'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      scriptId: json['script_id'] as String?,
      lineNumber: json['line_number'] as int?,
    );
  }

  /// Create from server log format
  factory LogEntry.fromServerLog(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.now(),
      level: _parseLevel(json['level'] as String? ?? 'info'),
      source: json['source'] as String? ?? 'server',
      message: json['message'] as String? ?? '',
      scriptId: json['script_id'] as String?,
      lineNumber: json['line_number'] as int?,
    );
  }

  static LogLevel _parseLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      case 'critical':
        return LogLevel.critical;
      default:
        return LogLevel.info;
    }
  }

  String get levelString => level.name.toUpperCase();

  String get formattedTimestamp {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
