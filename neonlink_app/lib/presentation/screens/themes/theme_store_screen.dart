import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

class ThemeStoreScreen extends StatelessWidget {
  const ThemeStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themes = [
      {'name': 'Cyberpunk', 'color': const Color(0xFF00F0FF)},
      {'name': 'Matrix', 'color': const Color(0xFF00FF00)},
      {'name': 'Racing Red', 'color': const Color(0xFFFF0000)},
      {'name': 'Apple Minimal', 'color': Colors.white},
    ];

    return Scaffold(
      backgroundColor: NeonTheme.background,
      appBar: AppBar(
        backgroundColor: NeonTheme.surface,
        title: const Text(
          'Theme Store',
          style: TextStyle(color: NeonTheme.primary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Themes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final theme = themes[index];
                return _buildThemeCard(theme['name'] as String, theme['color'] as Color);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(String name, Color accentColor) {
    return Card(
      color: NeonTheme.surface,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      NeonTheme.background,
                      accentColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getThemeIcon(name),
                  size: 32,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Click to apply',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getThemeIcon(String name) {
    switch (name) {
      case 'Cyberpunk':
        return Icons.computer;
      case 'Matrix':
        return Icons.code;
      case 'Racing Red':
        return Icons.directions_car;
      case 'Apple Minimal':
        return Icons.apple;
      default:
        return Icons.palette;
    }
  }
}
