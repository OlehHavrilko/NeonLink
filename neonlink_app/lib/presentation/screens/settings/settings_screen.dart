import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../services/backup_service.dart';
import '../../../services/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoReconnect = true;
  bool _tempAlerts = true;
  double _tempThreshold = 80;
  bool _vibration = true;
  int _reconnectAttempts = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonTheme.background,
      appBar: AppBar(
        backgroundColor: NeonTheme.surface,
        title: const Text(
          'Settings',
          style: TextStyle(color: NeonTheme.primary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Settings
            _buildSectionHeader('Display'),
            _buildSwitchTile('Always-On Screen', true),
            _buildSwitchTile('OLED Protection', false),
            _buildSliderSetting('Animation Intensity', 50),
            const SizedBox(height: 24),
            
            // Notifications
            _buildSectionHeader('Notifications'),
            _buildSwitchTile('Temperature Alerts', _tempAlerts, onChanged: (v) => setState(() => _tempAlerts = v)),
            _buildSliderSetting('Temperature Threshold', _tempThreshold, unit: '°C', onChanged: (v) => setState(() => _tempThreshold = v)),
            _buildSwitchTile('Vibration', _vibration, onChanged: (v) => setState(() => _vibration = v)),
            const SizedBox(height: 24),
            
            // Connection
            _buildSectionHeader('Connection'),
            _buildSwitchTile('Auto-Reconnect', _autoReconnect, onChanged: (v) => setState(() => _autoReconnect = v)),
            _buildSliderSetting('Reconnect Attempts', _reconnectAttempts.toDouble(), max: 10, onChanged: (v) => setState(() => _reconnectAttempts = v.toInt())),
            const SizedBox(height: 24),
            
            // Backup
            _buildSectionHeader('Backup'),
            _buildBackupSection(),
            const SizedBox(height: 24),
            
            // About
            _buildSectionHeader('About'),
            _buildInfoTile('Version', '1.0.0'),
            _buildInfoTile('Build', '1'),
            const SizedBox(height: 24),
            
            // Danger Zone
            _buildSectionHeader('Danger Zone'),
            _buildDestructiveButton('Clear Connection History'),
            const SizedBox(height: 16),
            _buildDestructiveButton('Reset to Defaults'),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection() {
    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.backup, color: NeonTheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Backup & Restore',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NeonTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Import'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NeonTheme.surface,
                      foregroundColor: NeonTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    try {
      await BackupService.instance.shareBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final backup = await BackupService.instance.loadBackup(result.files.single.path!);
        if (backup != null) {
          final success = await BackupService.instance.importSettings(backup);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Settings restored successfully' : 'Failed to restore settings'),
              ),
            );
            if (success) {
              NotificationService.instance.notifyBackupCreated();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: NeonTheme.primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, {void Function(bool)? onChanged}) {
    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white)),
            Switch(
              value: value,
              onChanged: onChanged ?? (newValue) {},
              activeThumbColor: NeonTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(String title, double value, {double max = 100, String unit = '%', void Function(double)? onChanged}) {
    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white)),
                Text(
                  '${value.toStringAsFixed(0)}$unit',
                  style: const TextStyle(color: NeonTheme.primary),
                ),
              ],
            ),
            Slider(
              value: value,
              min: 0,
              max: max,
              onChanged: onChanged ?? (newValue) {},
              activeColor: NeonTheme.primary,
              inactiveColor: Colors.grey[800],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Card(
      color: NeonTheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructiveButton(String text) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[900],
          foregroundColor: Colors.white,
        ),
        child: Text(text),
      ),
    );
  }
}
