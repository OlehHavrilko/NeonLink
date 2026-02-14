/// Script status
enum ScriptStatus {
  idle,
  running,
  completed,
  error,
  stopped,
}

/// Script info model
class ScriptInfo {
  final String id;
  final String name;
  final String description;
  final String interpreter;
  final String workingDirectory;
  final List<String> arguments;
  final ScriptStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final String? lastOutput;

  ScriptInfo({
    required this.id,
    required this.name,
    this.description = '',
    this.interpreter = 'python',
    this.workingDirectory = '',
    this.arguments = const [],
    this.status = ScriptStatus.idle,
    this.startedAt,
    this.completedAt,
    this.exitCode,
    this.lastOutput,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'interpreter': interpreter,
      'working_directory': workingDirectory,
      'arguments': arguments,
      'status': status.name,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'exit_code': exitCode,
      'last_output': lastOutput,
    };
  }

  factory ScriptInfo.fromJson(Map<String, dynamic> json) {
    return ScriptInfo(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      interpreter: json['interpreter'] as String? ?? 'python',
      workingDirectory: json['working_directory'] as String? ?? '',
      arguments: (json['arguments'] as List<dynamic>?)?.cast<String>() ?? [],
      status: ScriptStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ScriptStatus.idle,
      ),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      exitCode: json['exit_code'] as int?,
      lastOutput: json['last_output'] as String?,
    );
  }

  ScriptInfo copyWith({
    String? id,
    String? name,
    String? description,
    String? interpreter,
    String? workingDirectory,
    List<String>? arguments,
    ScriptStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? exitCode,
    String? lastOutput,
  }) {
    return ScriptInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      interpreter: interpreter ?? this.interpreter,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      arguments: arguments ?? this.arguments,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      exitCode: exitCode ?? this.exitCode,
      lastOutput: lastOutput ?? this.lastOutput,
    );
  }

  bool get isRunning => status == ScriptStatus.running;
  bool get isCompleted => status == ScriptStatus.completed;
  bool get hasError => status == ScriptStatus.error;

  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  String get durationString {
    final d = duration;
    if (d == null) return '--';
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    } else {
      return '${d.inSeconds}s';
    }
  }
}
