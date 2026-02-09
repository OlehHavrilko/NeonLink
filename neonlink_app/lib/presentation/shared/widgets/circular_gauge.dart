import 'package:flutter/material.dart';

class CircularGauge extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String unit;
  final Color? color;
  final bool showValue;
  final double size;

  const CircularGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    required this.label,
    this.unit = '%',
    this.color,
    this.showValue = true,
    this.size = 120,
  });

  @override
  State<CircularGauge> createState() => _CircularGaugeState();
}

class _CircularGaugeState extends State<CircularGauge> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(CircularGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
      );
      _animationController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(double value) {
    if (widget.color != null) return widget.color!;
    
    final percentage = value / (widget.max - widget.min) * 100;
    if (percentage < 50) return const Color(0xFF00FF88); // Safe - Green
    if (percentage < 80) return const Color(0xFFFFB800); // Warning - Yellow
    return const Color(0xFFFF3366); // Critical - Red
  }

  @override
  Widget build(BuildContext context) {
    final gaugeColor = _getStatusColor(widget.value);
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Background circle
          Positioned.fill(
            child: CustomPaint(
              painter: GaugePainter(
                value: 1.0,
                color: gaugeColor.withValues(alpha: 0.2),
                strokeWidth: 12,
              ),
            ),
          ),
          // Animated value arc
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: GaugePainter(
                    value: _animation.value / (widget.max - widget.min),
                    color: gaugeColor,
                    strokeWidth: 12,
                  ),
                );
              },
            ),
          ),
          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showValue)
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Text(
                        '${_animation.value.toStringAsFixed(1)}${widget.unit}',
                        style: TextStyle(
                          fontSize: widget.size * 0.2,
                          fontWeight: FontWeight.bold,
                          color: gaugeColor,
                        ),
                      );
                    },
                  ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.size * 0.1,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;

  GaugePainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw arc from -135 degrees to value
    const startAngle = -135 * (3.14159 / 180);
    final sweepAngle = value * 270 * (3.14159 / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
