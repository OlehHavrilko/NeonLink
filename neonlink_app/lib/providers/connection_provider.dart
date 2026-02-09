import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class ConnectionState {
  final ConnectionStatus status;
  final String? ip;
  final int? port;
  final String? error;

  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.ip,
    this.port,
    this.error,
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? ip,
    int? port,
    String? error,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      error: error ?? this.error,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get isDisconnected => status == ConnectionStatus.disconnected;
  bool get isReconnecting => status == ConnectionStatus.reconnecting;
  bool get hasError => status == ConnectionStatus.error;
}

class ConnectionNotifier extends Notifier<ConnectionState> {
  final webSocketService = WebSocketService();

  @override
  ConnectionState build() {
    return const ConnectionState();
  }

  Future<void> connect(String ip, int port) async {
    state = state.copyWith(status: ConnectionStatus.connecting, ip: ip, port: port);

    try {
      await webSocketService.connect(ip, port);
      state = state.copyWith(
        status: ConnectionStatus.connected,
        ip: ip,
        port: port,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        error: e.toString(),
      );
    }
  }

  void disconnect() {
    webSocketService.disconnect();
    state = const ConnectionState(status: ConnectionStatus.disconnected);
  }

  void retry() {
    if (state.ip != null && state.port != null) {
      connect(state.ip!, state.port!);
    }
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, ConnectionState>(
  ConnectionNotifier.new,
);
