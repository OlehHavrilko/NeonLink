import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/log_entry.dart';
import '../services/log_service.dart';

/// Log provider state
class LogProviderState {
  final List<LogEntry> logs;
  final bool isLoading;
  final LogLevel? filterLevel;
  final String? filterSource;
  final String searchText;
  final Map<LogLevel, int> stats;

  LogProviderState({
    this.logs = const [],
    this.isLoading = false,
    this.filterLevel,
    this.filterSource,
    this.searchText = '',
    this.stats = const {},
  });

  LogProviderState copyWith({
    List<LogEntry>? logs,
    bool? isLoading,
    LogLevel? filterLevel,
    String? filterSource,
    String? searchText,
    Map<LogLevel, int>? stats,
    bool clearLevelFilter = false,
    bool clearSourceFilter = false,
  }) {
    return LogProviderState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      filterLevel: clearLevelFilter ? null : (filterLevel ?? this.filterLevel),
      filterSource: clearSourceFilter ? null : (filterSource ?? this.filterSource),
      searchText: searchText ?? this.searchText,
      stats: stats ?? this.stats,
    );
  }
}

/// Log notifier
class LogNotifier extends Notifier<LogProviderState> {
  @override
  LogProviderState build() {
    _loadLogs();
    _loadStats();
    return LogProviderState();
  }

  Future<void> _loadLogs() async {
    state = state.copyWith(isLoading: true);

    final logs = await LogService.instance.getLogs(
      level: state.filterLevel,
      source: state.filterSource,
      searchText: state.searchText.isEmpty ? null : state.searchText,
      limit: 200,
    );

    state = state.copyWith(logs: logs, isLoading: false);
  }

  Future<void> _loadStats() async {
    final stats = await LogService.instance.getLogStats();
    state = state.copyWith(stats: stats);
  }

  /// Refresh logs
  Future<void> refresh() async {
    await _loadLogs();
    await _loadStats();
  }

  /// Set level filter
  void setLevelFilter(LogLevel? level) {
    state = state.copyWith(
      filterLevel: level,
      clearLevelFilter: level == null,
    );
    _loadLogs();
  }

  /// Set source filter
  void setSourceFilter(String? source) {
    state = state.copyWith(
      filterSource: source,
      clearSourceFilter: source == null,
    );
    _loadLogs();
  }

  /// Set search text
  void setSearchText(String text) {
    state = state.copyWith(searchText: text);
    _loadLogs();
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      clearLevelFilter: true,
      clearSourceFilter: true,
      searchText: '',
    );
    _loadLogs();
  }

  /// Add log from server
  Future<void> addLogFromServer(Map<String, dynamic> json) async {
    final entry = LogEntry.fromServerLog(json);
    await LogService.instance.addLog(entry);
    await _loadLogs();
    await _loadStats();
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    await LogService.instance.clearAllLogs();
    await _loadLogs();
    await _loadStats();
  }

  /// Clear old logs
  Future<void> clearOldLogs(int days) async {
    await LogService.instance.clearOldLogs(days);
    await _loadLogs();
    await _loadStats();
  }

  /// Export logs
  Future<String> exportLogs({LogLevel? level}) async {
    return await LogService.instance.exportLogs(level: level);
  }
}

/// Log provider
final logProvider = NotifierProvider<LogNotifier, LogProviderState>(
  LogNotifier.new,
);

/// Log sources provider
final logSourcesProvider = FutureProvider<List<String>>((ref) async {
  return await LogService.instance.getSources();
});
