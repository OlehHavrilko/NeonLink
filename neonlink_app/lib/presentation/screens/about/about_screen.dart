import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../providers/connection_provider.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      backgroundColor: NeonTheme.background,
      appBar: AppBar(
        backgroundColor: NeonTheme.surface,
        title: const Text(
          'About',
          style: TextStyle(color: NeonTheme.text),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: NeonTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: NeonTheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NeonTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.dashboard_customize,
                size: 64,
                color: NeonTheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // App Name
            const Text(
              'NeonLink',
              style: TextStyle(
                color: NeonTheme.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'PC Hardware Monitoring',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 32),

            // Connection Status
            _buildInfoCard(
              'Connection Status',
              [
                _buildInfoRow('Server', connectionState.ip != null ? '${connectionState.ip}:${connectionState.port}' : 'Not connected'),
                _buildInfoRow('Status', connectionState.isConnected ? 'Connected' : 'Disconnected'),
              ],
            ),

            const SizedBox(height: 16),

            // App Features
            _buildFeaturesCard(),

            const SizedBox(height: 16),

            // Developer Info
            _buildInfoCard(
              'Developer',
              [
                _buildInfoRow('Author', 'NeonLink Team'),
                _buildInfoRow('License', 'MIT License'),
                _buildInfoRow('Repository', 'GitHub'),
              ],
            ),

            const SizedBox(height: 24),

            // Check Updates Button
            ElevatedButton.icon(
              onPressed: () => _checkForUpdates(context),
              icon: const Icon(Icons.system_update),
              label: const Text('Check for Updates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),

            const SizedBox(height: 32),

            // Footer
            Text(
              '© 2024 NeonLink. All rights reserved.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: NeonTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    final features = [
      {'icon': Icons.speed, 'title': 'Real-time Monitoring'},
      {'icon': Icons.show_chart, 'title': 'Graph Visualization'},
      {'icon': Icons.code, 'title': 'Script Management'},
      {'icon': Icons.article, 'title': 'Event Logging'},
      {'icon': Icons.notifications, 'title': 'Push Notifications'},
      {'icon': Icons.backup, 'title': 'Backup & Restore'},
    ];

    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Features',
              style: TextStyle(
                color: NeonTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: NeonTheme.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 16,
                      color: NeonTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      f['title'] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _checkForUpdates(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeonTheme.surface,
        title: const Text(
          'Check for Updates',
          style: TextStyle(color: NeonTheme.text),
        ),
        content: const Text(
          'You are running the latest version (1.0.0).',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
