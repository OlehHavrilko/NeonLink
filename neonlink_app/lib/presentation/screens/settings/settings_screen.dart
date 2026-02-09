import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            _buildSwitchTile('Temperature Alerts', true),
            _buildSliderSetting('Temperature Threshold', 80, unit: '°C'),
            _buildSwitchTile('Vibration', true),
            const SizedBox(height: 24),
            
            // Connection
            _buildSectionHeader('Connection'),
            _buildSwitchTile('Auto-Reconnect', true),
            _buildSliderSetting('Reconnect Attempts', 5, max: 10),
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

  Widget _buildSwitchTile(String title, bool value) {
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
              onChanged: (newValue) {},
              activeThumbColor: NeonTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(String title, double value, {double max = 100, String unit = '%'}) {
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
              onChanged: (newValue) {},
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
