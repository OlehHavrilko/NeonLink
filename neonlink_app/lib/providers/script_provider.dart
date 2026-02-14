import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/script_info.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';

/// WebSocket service provider
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Script provider state
class ScriptProviderState {
  final List<ScriptInfo> scripts;
  final ScriptInfo? selectedScript;
  final bool isLoading;
  final String? error;

  ScriptProviderState({
    this.scripts = const [],
    this.selectedScript,
    this.isLoading = false,
    this.error,
  });

  ScriptProviderState copyWith({
    List<ScriptInfo>? scripts,
    ScriptInfo? selectedScript,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return ScriptProviderState(
      scripts: scripts ?? this.scripts,
      selectedScript: clearSelected ? null : (selectedScript ?? this.selectedScript),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Script notifier
class ScriptNotifier extends Notifier<ScriptProviderState> {
  StreamSubscription? _responseSubscription;

  @override
  ScriptProviderState build() {
    ref.onDispose(() {
      _responseSubscription?.cancel();
    });
    _listenToResponses();
    return ScriptProviderState();
  }

  void _listenToResponses() {
    final wsService = ref.read(websocketServiceProvider);
    _responseSubscription?.cancel();
    _responseSubscription = wsService.responseStream.listen(_handleResponse);
  }

  void _handleResponse(Map<String, dynamic> response) {
    final command = response['command'] as String?;

    if (command == 'getScripts') {
      _handleGetScriptsResponse(response);
    } else if (command == 'runScript') {
      _handleRunScriptResponse(response);
    } else if (command == 'stopScript') {
      _handleStopScriptResponse(response);
    }
  }

  void _handleGetScriptsResponse(Map<String, dynamic> response) {
    if (response['success'] == true) {
      final result = response['result'] as Map<String, dynamic>?;
      if (result != null) {
        final scriptsList = result['scripts'] as List<dynamic>? ?? [];
        final scripts = scriptsList
            .map((e) => ScriptInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(scripts: scripts, isLoading: false);
      }
    } else {
      state = state.copyWith(
        error: response['error'] as String?,
        isLoading: false,
      );
    }
  }

  void _handleRunScriptResponse(Map<String, dynamic> response) {
    if (response['success'] == true) {
      final scriptId = response['script_id'] as String?;
      if (scriptId != null) {
        // Update script status
        final scripts = state.scripts.map((s) {
          if (s.id == scriptId) {
            return s.copyWith(
              status: ScriptStatus.running,
              startedAt: DateTime.now(),
            );
          }
          return s;
        }).toList();

        state = state.copyWith(scripts: scripts);

        // Find script name for notification
        final script = scripts.firstWhere(
          (s) => s.id == scriptId,
          orElse: () => ScriptInfo(id: scriptId, name: 'Script'),
        );

        NotificationService.instance.notifyScriptStarted(script.name);
      }
    } else {
      state = state.copyWith(error: response['error'] as String?);
    }
  }

  void _handleStopScriptResponse(Map<String, dynamic> response) {
    if (response['success'] == true) {
      final scriptId = response['script_id'] as String?;
      if (scriptId != null) {
        final scripts = state.scripts.map((s) {
          if (s.id == scriptId) {
            return s.copyWith(
              status: ScriptStatus.stopped,
              completedAt: DateTime.now(),
            );
          }
          return s;
        }).toList();

        state = state.copyWith(scripts: scripts);
      }
    }
  }

  /// Fetch scripts from server
  Future<void> fetchScripts() async {
    final wsService = ref.read(websocketServiceProvider);
    if (!wsService.isConnected) {
      state = state.copyWith(error: 'Not connected to server');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    wsService.sendCommand('{"command":"getScripts"}');
  }

  /// Run script
  Future<void> runScript(String scriptId) async {
    final wsService = ref.read(websocketServiceProvider);
    if (!wsService.isConnected) {
      state = state.copyWith(error: 'Not connected to server');
      return;
    }

    wsService.sendCommand('{"command":"runScript","script_id":"$scriptId"}');
  }

  /// Stop script
  Future<void> stopScript(String scriptId) async {
    final wsService = ref.read(websocketServiceProvider);
    if (!wsService.isConnected) {
      state = state.copyWith(error: 'Not connected to server');
      return;
    }

    wsService.sendCommand('{"command":"stopScript","script_id":"$scriptId"}');
  }

  /// Select script
  void selectScript(ScriptInfo? script) {
    state = state.copyWith(
      selectedScript: script,
      clearSelected: script == null,
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Script provider
final scriptProvider = NotifierProvider<ScriptNotifier, ScriptProviderState>(
  ScriptNotifier.new,
);
