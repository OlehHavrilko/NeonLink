import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/models/log_entry.dart';

/// Service for local log storage
class LogService {
  static LogService? _instance;
  static Database? _database;

  LogService._();

  static LogService get instance {
    _instance ??= LogService._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'neonlink_logs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        level TEXT NOT NULL,
        source TEXT NOT NULL,
        message TEXT NOT NULL,
        script_id TEXT,
        line_number INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_logs_timestamp ON logs(timestamp)');
    await db.execute('CREATE INDEX idx_logs_level ON logs(level)');
    await db.execute('CREATE INDEX idx_logs_source ON logs(source)');
  }

  /// Add a log entry
  Future<int> addLog(LogEntry entry) async {
    final db = await database;
    return await db.insert('logs', entry.toJson()..remove('id'));
  }

  /// Get logs with filtering
  Future<List<LogEntry>> getLogs({
    LogLevel? level,
    String? source,
    String? searchText,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (level != null) {
      whereClause += ' AND level = ?';
      whereArgs.add(level.name);
    }

    if (source != null) {
      whereClause += ' AND source = ?';
      whereArgs.add(source);
    }

    if (searchText != null && searchText.isNotEmpty) {
      whereClause += ' AND message LIKE ?';
      whereArgs.add('%$searchText%');
    }

    final results = await db.query(
      'logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((e) => LogEntry.fromJson(e)).toList();
  }

  /// Get log count
  Future<int> getLogCount({LogLevel? level}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM logs${level != null ? ' WHERE level = ?' : ''}',
      level != null ? [level.name] : null,
    );
    return result.first['count'] as int;
  }

  /// Get unique sources
  Future<List<String>> getSources() async {
    final db = await database;
    final results = await db.rawQuery('SELECT DISTINCT source FROM logs ORDER BY source');
    return results.map((e) => e['source'] as String).toList();
  }

  /// Get log statistics
  Future<Map<LogLevel, int>> getLogStats() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT level, COUNT(*) as count FROM logs GROUP BY level',
    );

    final stats = <LogLevel, int>{};
    for (final row in results) {
      final levelStr = row['level'] as String;
      final count = row['count'] as int;
      try {
        stats[LogLevel.values.firstWhere((e) => e.name == levelStr)] = count;
      } catch (_) {
        // Skip unknown levels
      }
    }
    return stats;
  }

  /// Clear old logs
  Future<int> clearOldLogs(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return await db.delete(
      'logs',
      where: 'timestamp < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// Clear all logs
  Future<int> clearAllLogs() async {
    final db = await database;
    return await db.delete('logs');
  }

  /// Export logs to string
  Future<String> exportLogs({LogLevel? level}) async {
    final logs = await getLogs(level: level, limit: 10000);
    final buffer = StringBuffer();

    for (final log in logs.reversed) {
      buffer.writeln('${log.formattedTimestamp} [${log.levelString}] [${log.source}] ${log.message}');
    }

    return buffer.toString();
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
