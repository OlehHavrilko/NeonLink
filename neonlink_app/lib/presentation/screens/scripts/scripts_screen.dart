import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../providers/script_provider.dart';
import '../../../providers/connection_provider.dart';
import '../../../data/models/script_info.dart';

class ScriptsScreen extends ConsumerStatefulWidget {
  const ScriptsScreen({super.key});

  @override
  ConsumerState<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends ConsumerState<ScriptsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch scripts when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connection = ref.read(connectionProvider);
      if (connection.isConnected) {
        ref.read(scriptProvider.notifier).fetchScripts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scriptState = ref.watch(scriptProvider);
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      backgroundColor: NeonTheme.background,
      appBar: AppBar(
        backgroundColor: NeonTheme.surface,
        title: const Text(
          'Scripts',
          style: TextStyle(color: NeonTheme.text),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: NeonTheme.primary),
            onPressed: connectionState.isConnected
                ? () => ref.read(scriptProvider.notifier).fetchScripts()
                : null,
          ),
        ],
      ),
      body: _buildBody(scriptState, connectionState),
    );
  }

  Widget _buildBody(ScriptProviderState scriptState, connectionState) {
    if (!connectionState.isConnected) {
      return _buildNotConnected();
    }

    if (scriptState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: NeonTheme.primary),
      );
    }

    if (scriptState.error != null) {
      return _buildError(scriptState.error!);
    }

    if (scriptState.scripts.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(scriptProvider.notifier).fetchScripts(),
      color: NeonTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: scriptState.scripts.length,
        itemBuilder: (context, index) {
          return _buildScriptCard(scriptState.scripts[index]);
        },
      ),
    );
  }

  Widget _buildNotConnected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Not connected to server',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a NeonLink server to manage scripts',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Colors.red[300]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(scriptProvider.notifier).fetchScripts(),
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.code_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No scripts available',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scripts will appear here when added to the server',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard(ScriptInfo script) {
    return Card(
      color: NeonTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(script.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        script.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (script.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          script.description,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.terminal, script.interpreter),
                const SizedBox(width: 8),
                if (script.durationString != '--')
                  _buildInfoChip(Icons.timer, script.durationString),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (script.isRunning)
                  ElevatedButton.icon(
                    onPressed: () => _stopScript(script.id),
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _runScript(script.id),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Run'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NeonTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ScriptStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case ScriptStatus.running:
        icon = Icons.play_circle;
        color = NeonTheme.safe;
        break;
      case ScriptStatus.completed:
        icon = Icons.check_circle;
        color = NeonTheme.primary;
        break;
      case ScriptStatus.error:
        icon = Icons.error;
        color = Colors.red;
        break;
      case ScriptStatus.stopped:
        icon = Icons.stop_circle;
        color = Colors.orange;
        break;
      case ScriptStatus.idle:
      default:
        icon = Icons.circle_outlined;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 32);
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NeonTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _runScript(String scriptId) {
    ref.read(scriptProvider.notifier).runScript(scriptId);
  }

  void _stopScript(String scriptId) {
    ref.read(scriptProvider.notifier).stopScript(scriptId);
  }
}
