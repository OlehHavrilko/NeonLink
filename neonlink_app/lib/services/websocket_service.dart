import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../core/constants/app_constants.dart';
import '../data/models/telemetry_data.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  String? _lastIp;
  int? _lastPort;
  
  final _messageController = StreamController<TelemetryData>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  Stream<TelemetryData> get telemetryStream => _messageController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  ConnectionStatus get currentStatus => _statusController.hasListener 
      ? ConnectionStatus.connected 
      : ConnectionStatus.disconnected;

  Future<void> connect(String ip, int port) async {
    _lastIp = ip;
    _lastPort = port;
    _reconnectAttempts = 0;
    _statusController.add(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$ip:$port/ws');
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection
      await _channel!.ready.timeout(AppConstants.connectionTimeout);

      // Start heartbeat
      _heartbeatTimer = Timer.periodic(
        AppConstants.heartbeatInterval,
        (_) => _sendPing(),
      );

      // Listen for messages
      _channel!.stream.listen(
        _onMessage,
        onError: _handleError,
        onDone: () => _handleDisconnect(),
      );

      _statusController.add(ConnectionStatus.connected);
    } catch (e) {
      _statusController.add(ConnectionStatus.error);
      _handleDisconnect();
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = TelemetryData.fromJson(jsonDecode(message));
      _messageController.add(data);
    } catch (e) {
      // Log parsing error
      debugPrint('Telemetry parse error: $e');
    }
  }

  void _sendPing() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'command': 'ping'}));
    }
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) {
      _statusController.add(ConnectionStatus.error);
      _statusController.add(ConnectionStatus.disconnected);
      return;
    }

    _reconnectAttempts++;
    _statusController.add(ConnectionStatus.reconnecting);

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final delay = Duration(
      seconds: AppConstants.reconnectionDelayBase.inSeconds * (1 << (_reconnectAttempts - 1)),
    );

    _reconnectTimer = Timer(delay, () {
      if (_lastIp != null && _lastPort != null) {
        connect(_lastIp!, _lastPort!);
      }
    });
  }

  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _handleDisconnect();
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    _channel?.sink.close(status.goingAway);
    _channel = null;
    
    _statusController.add(ConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}
