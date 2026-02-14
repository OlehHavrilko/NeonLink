import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/discovery_service.dart';
import '../../../providers/connection_provider.dart';
import '../../shared/widgets/status_indicator.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: AppConstants.defaultPort.toString());
  final List<DiscoveredPC> _discoveredPCs = [];
  DiscoveryService? _discoveryService;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _discoveryService?.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    _discoveryService = DiscoveryService();
    _discoveryService!.startDiscovery();
    _discoveryService!.discoveredPCs.listen((pc) {
      if (mounted) {
        setState(() {
          if (!_discoveredPCs.any((p) => p.ip == pc.ip)) {
            _discoveredPCs.add(pc);
          }
        });
      }
    });
  }

  Future<void> _scanQR() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted) return;
    }

    // QR scanning implementation would go here
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Scanner: Point camera at QR code')),
      );
    }
  }

  void _onQRCodeScanned(String data) {
    // Parse: neonlink://ip:port
    if (data.startsWith('neonlink://')) {
      final parts = data.replaceFirst('neonlink://', '').split(':');
      if (parts.length >= 2) {
        _ipController.text = parts[0];
        _portController.text = parts[1];
      }
    } else if (data.contains(':')) {
      final parts = data.split(':');
      _ipController.text = parts[0];
      if (parts.length > 1) _portController.text = parts[1];
    }
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text) ?? AppConstants.defaultPort;

    if (ip.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter IP address')),
        );
      }
      return;
    }

    try {
      await ref.read(connectionProvider.notifier).connect(ip, port);
      if (mounted) {
        final state = ref.read(connectionProvider);
        if (state.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to $ip:$port')),
          );
        } else if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection failed: ${state.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F35),
        title: const Text(
          'Connect to PC',
          style: TextStyle(color: Color(0xFF00F0FF)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QR Scanner Button
            ElevatedButton.icon(
              onPressed: _scanQR,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Manual Input
            const Text(
              'Manual Connection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ipController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'PC IP Address',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF1A1F35),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00F0FF)),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _portController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Port',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF1A1F35),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00F0FF)),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF00AA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('CONNECT'),
            ),
            const SizedBox(height: 24),

            // Discovered PCs
            if (_discoveredPCs.isNotEmpty) ...[
              const Text(
                'Discovered PCs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._discoveredPCs.map((pc) => Card(
                color: const Color(0xFF1A1F35),
                child: ListTile(
                  leading: const StatusIndicator(level: StatusLevel.safe),
                  title: Text(
                    pc.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${pc.ip}:${pc.port}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    _ipController.text = pc.ip;
                    _portController.text = pc.port.toString();
                  },
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
