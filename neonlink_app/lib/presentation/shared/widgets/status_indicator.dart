import 'package:flutter/material.dart';

enum StatusLevel {
  safe,
  warning,
  critical,
  disconnected,
}

class StatusIndicator extends StatelessWidget {
  final StatusLevel level;
  final String label;
  final bool animate;

  const StatusIndicator({
    super.key,
    required this.level,
    this.label = '',
    this.animate = true,
  });

  Color _getColor() {
    switch (level) {
      case StatusLevel.safe:
        return const Color(0xFF00FF88);
      case StatusLevel.warning:
        return const Color(0xFFFFB800);
      case StatusLevel.critical:
        return const Color(0xFFFF3366);
      case StatusLevel.disconnected:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              if (animate && level != StatusLevel.disconnected)
                BoxShadow(
                  color: color,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
