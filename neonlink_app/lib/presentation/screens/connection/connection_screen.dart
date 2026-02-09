import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/discovery_service.dart';
import '../../../services/websocket_service.dart';
import '../../../core/theme/neon_theme.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '9876');
  final DiscoveryService _discoveryService = DiscoveryService();
  
  List<DiscoveredPC> _discoveredPCs = [];
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() async {
    await _discoveryService.startDiscovery();
    _discoveryService.discoveredPCs.listen((pc) {
      if (mounted) {
        setState(() {
          if (!_discoveredPCs.any((p) => p.ip == pc.ip)) {
            _discoveredPCs.add(pc);
          }
        });
      }
    });
  }

  Future<void> _connectToPC(String ip, int port) async {
    setState(() => _connectionStatus = ConnectionStatus.connecting);
    _errorMessage = null;

    try {
      final wsService = ref.read(webSocketServiceProvider);
      await wsService.connect(ip, port);
      
      if (mounted) {
        setState(() => _connectionStatus = ConnectionStatus.connected);
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = ConnectionStatus.error;
          _errorMessage = 'Connection failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEONLINK',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 32,
                  color: NeonTheme.primary,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PC Hardware Monitor',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 18,
                  color: NeonTheme.text.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              
              // Discovered PCs
              if (_discoveredPCs.isNotEmpty) ...[
                const Text(
                  'Discovered PCs',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    color: NeonTheme.text,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _discoveredPCs.length,
                    itemBuilder: (context, index) {
                      final pc = _discoveredPCs[index];
                      return Card(
                        color: NeonTheme.surface,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.computer,
                            color: NeonTheme.primary,
                          ),
                          title: Text(
                            pc.name,
                            style: const TextStyle(
                              fontFamily: 'Rajdhani',
                              color: NeonTheme.text,
                            ),
                          ),
                          subtitle: Text(
                            '${pc.ip}:${pc.port}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              color: NeonTheme.text.withOpacity(0.7),
                            ),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _connectToPC(pc.ip, pc.port),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NeonTheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Connect'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Manual Connection
              const Text(
                'Manual Connection',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 16,
                  color: NeonTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ipController,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  color: NeonTheme.text,
                ),
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  labelStyle: TextStyle(
                    fontFamily: 'Rajdhani',
                    color: NeonTheme.text.withOpacity(0.7),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: NeonTheme.primary.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NeonTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  color: NeonTheme.text,
                ),
                decoration: InputDecoration(
                  labelText: 'Port',
                  labelStyle: TextStyle(
                    fontFamily: 'Rajdhani',
                    color: NeonTheme.text.withOpacity(0.7),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: NeonTheme.primary.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: NeonTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NeonTheme.critical.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeonTheme.critical),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      color: NeonTheme.critical,
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Connect Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _connectionStatus == ConnectionStatus.connecting
                      ? null
                      : () {
                          final ip = _ipController.text.trim();
                          final port = int.tryParse(_portController.text) ?? 9876;
                          if (ip.isNotEmpty) {
                            _connectToPC(ip, port);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeonTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _connectionStatus == ConnectionStatus.connecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black),
                        )
                      : const Text(
                          'CONNECT',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
