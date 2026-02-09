import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonTheme.background,
      appBar: AppBar(
        backgroundColor: NeonTheme.surface,
        title: const Text(
          'Control Panel',
          style: TextStyle(color: NeonTheme.primary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fan Control Section
            _buildSectionHeader('Fan Control'),
            Card(
              color: NeonTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSlider('Fan Speed', 0, 100, (value) {}),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPresetButton('Quiet'),
                        _buildPresetButton('Balanced', isSelected: true),
                        _buildPresetButton('Performance'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // RGB Control Section
            _buildSectionHeader('RGB Lighting'),
            Card(
              color: NeonTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildColorButton(Colors.red),
                        _buildColorButton(Colors.green),
                        _buildColorButton(Colors.blue),
                        _buildColorButton(Colors.cyan),
                        _buildColorButton(Colors.purple),
                        _buildColorButton(Colors.yellow),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown('Effect', ['Static', 'Breathing', 'Wave', 'Reactive']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Power Profiles Section
            _buildSectionHeader('Power Profiles'),
            Card(
              color: NeonTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileTile('Power Saver', Icons.battery_saver),
                    _buildProfileTile('Balanced', Icons.balance, isSelected: true),
                    _buildProfileTile('High Performance', Icons.speed),
                  ],
                ),
              ),
            ),
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

  Widget _buildSlider(String label, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            const Text('50%', style: TextStyle(color: NeonTheme.primary)),
          ],
        ),
        Slider(
          value: 50,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: NeonTheme.primary,
          inactiveColor: Colors.grey[800],
        ),
      ],
    );
  }

  Widget _buildPresetButton(String text, {bool isSelected = false}) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? NeonTheme.primary : NeonTheme.surface,
        foregroundColor: isSelected ? Colors.black : Colors.white,
        side: BorderSide(
          color: isSelected ? NeonTheme.primary : Colors.grey[600]!,
        ),
      ),
      child: Text(text),
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Effect',
        labelStyle: TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: NeonTheme.primary),
        ),
      ),
      dropdownColor: NeonTheme.surface,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: const TextStyle(color: Colors.white)),
      )).toList(),
      onChanged: (value) {},
    );
  }

  Widget _buildProfileTile(String title, IconData icon, {bool isSelected = false}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? NeonTheme.primary : Colors.grey),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: isSelected 
          ? const Icon(Icons.check_circle, color: NeonTheme.primary)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      selected: isSelected,
      onTap: () {},
    );
  }
}
