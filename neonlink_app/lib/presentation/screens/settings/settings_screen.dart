import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tune, size: 64, color: NeonTheme.accent),
          const SizedBox(height: 16),
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 24,
              color: NeonTheme.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 16,
              color: NeonTheme.text.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
