import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';

class DiscoveredPC {
  final String ip;
  final int port;
  final String name;
  final DateTime discoveredAt;

  DiscoveredPC({
    required this.ip,
    required this.port,
    required this.name,
    required this.discoveredAt,
  });
}

class DiscoveryService {
  RawDatagramSocket? _socket;
  final _discoveryController = StreamController<DiscoveredPC>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  Timer? _broadcastTimer;
  bool _isDiscovering = false;

  Stream<DiscoveredPC> get discoveredPCs => _discoveryController.stream;
  Stream<String> get errors => _errorController.stream;
  bool get isDiscovering => _isDiscovering;

  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      debugPrint('[DEBUG] Discovery already in progress, skipping');
      return;
    }
    _isDiscovering = true;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
      );

      debugPrint('[DEBUG] Discovery socket bound to port ${AppConstants.discoveryPort}');

      _socket!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            _processDatagram();
          }
        },
        onError: (error) {
          debugPrint('[DEBUG] Discovery socket error: $error');
          _errorController.add('Socket error: $error');
          stopDiscovery();
        },
      );

      // Send broadcast query every 2 seconds
      _broadcastTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _sendBroadcastQuery(),
      );
    } catch (e) {
      debugPrint('[DEBUG] Failed to start discovery: $e');
      // DEBUG: Log more details about the error
      debugPrint('[DEBUG] Discovery error type: ${e.runtimeType}');
      _errorController.add('Failed to start discovery: $e');
      _isDiscovering = false;
      rethrow;
    }
  }

  void _sendBroadcastQuery() {
    const message = 'NEONLINK_DISCOVER';
    _socket!.send(
      message.codeUnits,
      InternetAddress('255.255.255.255'),
      AppConstants.discoveryPort,
    );
  }

  void _processDatagram() {
    final datagram = _socket!.receive();
    if (datagram != null) {
      final message = String.fromCharCodes(datagram.data);
      
      // Parse "NEONLINK:IP:PORT:NAME"
      if (message.startsWith('NEONLINK:')) {
        final parts = message.split(':');
        if (parts.length >= 4) {
          final pc = DiscoveredPC(
            ip: parts[1],
            port: int.parse(parts[2]),
            name: parts[3],
            discoveredAt: DateTime.now(),
          );
          _discoveryController.add(pc);
        }
      }
    }
  }

  void stopDiscovery() {
    _isDiscovering = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stopDiscovery();
    _discoveryController.close();
    _errorController.close();
  }
}
