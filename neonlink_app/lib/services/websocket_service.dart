import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../core/constants/app_constants.dart';
import '../data/models/telemetry_data.dart';
import 'command_builder.dart';

/// Статус соединения WebSocket
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Сервис WebSocket для коммуникации с NeonLink Server
/// Версия API: 1.0.0
class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  String? _lastIp;
  int? _lastPort;
  
  /// Текущий статус соединения
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  
  /// Контроллеры потоков
  final _messageController = StreamController<TelemetryData>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _responseController = StreamController<Map<String, dynamic>>.broadcast();

  /// Поток телеметрии
  Stream<TelemetryData> get telemetryStream => _messageController.stream;
  
  /// Поток статуса соединения
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  /// Поток ошибок
  Stream<String> get errorStream => _errorController.stream;
  
  /// Поток ответов на команды
  Stream<Map<String, dynamic>> get responseStream => _responseController.stream;
  
  /// Текущий статус соединения
  ConnectionStatus get currentStatus => _currentStatus;
  
  /// Подключен ли WebSocket
  bool get isConnected => _currentStatus == ConnectionStatus.connected;

  /// Подключение к серверу
  Future<void> connect(String ip, int port) async {
    _lastIp = ip;
    _lastPort = port;
    _reconnectAttempts = 0;
    _updateStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$ip:$port/ws');
      _channel = WebSocketChannel.connect(uri);

      // Ожидание подключения с таймаутом
      await _channel!.ready.timeout(AppConstants.connectionTimeout);

      // Запуск heartbeat
      _startHeartbeat();

      // Слушаем входящие сообщения
      _channel!.stream.listen(
        _onMessage,
        onError: _handleError,
        onDone: () => _handleDisconnect(),
      );

      _updateStatus(ConnectionStatus.connected);
    } catch (e) {
      _updateStatus(ConnectionStatus.error);
      _errorController.add('Connection failed: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  /// Обработка входящего сообщения
  void _onMessage(dynamic message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (ResponseParser.isTelemetry(json)) {
        // Это телеметрия
        final data = TelemetryData.fromJson(json);
        _messageController.add(data);
      } else if (ResponseParser.isCommandResponse(json)) {
        // Это ответ на команду
        _responseController.add(json);
      } else {
        // Неизвестный формат
        debugPrint('Unknown message format: $json');
      }
    } catch (e) {
      _errorController.add('Parse error: $e');
      debugPrint('Message parse error: $e');
    }
  }

  /// Отправка команды
  void sendCommand(String commandJson) {
    if (_channel == null || !isConnected) {
      _errorController.add('Not connected to server');
      return;
    }
    _channel!.sink.add(commandJson);
  }

  /// Отправка команды с ожиданием ответа
  Future<T> sendCommandAsync<T>(
    String commandJson, {
    Duration timeout = const Duration(seconds: 10),
    required T Function(Map<String, dynamic>) parser,
  }) async {
    if (_channel == null || !isConnected) {
      throw StateError('Not connected to server');
    }

    final command = jsonDecode(commandJson) as Map<String, dynamic>;
    final commandName = command['command'] as String;

    final completer = Completer<T>();
    late StreamSubscription subscription;

    subscription = _responseController.stream.listen((response) {
      if (response['command'] == commandName) {
        subscription.cancel();
        if (response['success'] == true) {
          try {
            completer.complete(parser(response));
          } catch (e) {
            completer.completeError(e);
          }
        } else {
          completer.completeError(Exception(response['error'] ?? 'Unknown error'));
        }
      }
    });

    // Отправка команды
    _channel!.sink.add(commandJson);

    // Таймаут
    return completer.future.timeout(timeout, onTimeout: () {
      subscription.cancel();
      throw TimeoutException('Command $commandName timed out');
    });
  }

  /// Ping сервера
  Future<int> ping() async {
    final result = await sendCommandAsync<int>(
      CommandBuilder.ping(),
      parser: (json) => json['timestamp'] as int? ?? 0,
    );
    return result;
  }

  /// Получение статуса сервера
  Future<StatusResponse> getStatus() async {
    return sendCommandAsync<StatusResponse>(
      CommandBuilder.getStatus(),
      parser: (json) => StatusResponse.fromJson(json['result'] as Map<String, dynamic>),
    );
  }

  /// Установка интервала опроса
  Future<bool> setPollingInterval(int intervalMs) async {
    try {
      final result = await sendCommandAsync<PollingIntervalResponse>(
        CommandBuilder.setPollingInterval(intervalMs),
        parser: (json) => PollingIntervalResponse.fromJson(json),
      );
      return result.success;
    } catch (e) {
      debugPrint('Failed to set polling interval: $e');
      return false;
    }
  }

  /// Запуск heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      AppConstants.heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  /// Отправка heartbeat
  void _sendHeartbeat() {
    if (_channel != null && isConnected) {
      _channel!.sink.add(CommandBuilder.ping());
    }
  }

  /// Обработка отключения
  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) {
      _updateStatus(ConnectionStatus.error);
      _updateStatus(ConnectionStatus.disconnected);
      return;
    }

    _reconnectAttempts++;
    _updateStatus(ConnectionStatus.reconnecting);

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

  /// Обработка ошибки
  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _errorController.add('WebSocket error: $error');
    _handleDisconnect();
  }

  /// Обновление статуса
  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Отключение от сервера
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    _channel?.sink.close(status.goingAway);
    _channel = null;
    
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Освобождение ресурсов
  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
    _errorController.close();
    _responseController.close();
  }
}
