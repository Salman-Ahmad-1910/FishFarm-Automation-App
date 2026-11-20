import 'dart:math' as math;

import 'package:flutter/material.dart';

class PressureGauge extends StatelessWidget {
  final double? value;
  final Color color;

  const PressureGauge({super.key, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value ?? 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return SizedBox(
          width: 170,
          height: 100,
          child: CustomPaint(
            painter: _GaugePainter(
              value: animatedValue,
              color: color,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  value == null ? '--' : value!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.width / 2 - 12;

    final bgPaint = Paint()
      ..color = const Color(0xFF2A3F52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    final fraction = (value / 250).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      fraction * math.pi,
      false,
      progressPaint,
    );

    // Labels
    for (var i = 0; i <= 2; i++) {
      final frac = i / 2.0;
      final angle = math.pi + frac * math.pi;
      final label = (frac * 250).toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFFAAB8C4),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(
        center.dx + (radius + 18) * math.cos(angle) - tp.width / 2,
        center.dy + (radius + 18) * math.sin(angle) - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
