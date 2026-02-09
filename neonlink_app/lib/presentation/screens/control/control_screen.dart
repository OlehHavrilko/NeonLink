import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings_remote, size: 64, color: NeonTheme.primary),
          const SizedBox(height: 16),
          const Text(
            'CONTROL PANEL',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 24,
              color: NeonTheme.primary,
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
