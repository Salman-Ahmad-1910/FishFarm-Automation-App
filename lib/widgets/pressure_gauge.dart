import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Half-circle pressure gauge (0 - 250 kPa) that scales to the width it gets.
class PressureGauge extends StatelessWidget {
  final double? value;
  final Color color;

  const PressureGauge({super.key, required this.value, required this.color});

  static const double _maxKpa = 250;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 220.0;
        final width = available.clamp(130.0, 260.0).toDouble();
        final height = width * 0.62;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value ?? 0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            return SizedBox(
              width: width,
              height: height,
              child: CustomPaint(
                painter: _GaugePainter(value: animated, color: color),
                child: Align(
                  alignment: const Alignment(0, 0.45),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value == null ? '--' : value!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: width * 0.15,
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
    final stroke = size.width * 0.07;
    final radius = size.width / 2 - stroke;
    final center = Offset(size.width / 2, size.height * 0.80);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = const Color(0xFF2A3F52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);
    final fraction =
        (value / PressureGauge._maxKpa).clamp(0.0, 1.0).toDouble();
    if (fraction > 0) {
      canvas.drawArc(rect, math.pi, fraction * math.pi, false, progressPaint);
    }

    // Scale labels under the two ends of the arc.
    void label(String text, double centerX) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: (size.width * 0.06).clamp(9.0, 13.0).toDouble(),
            color: const Color(0xFFAAB8C4),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(centerX - tp.width / 2, center.dy + stroke / 2 + 2),
      );
    }

    label('0', center.dx - radius);
    label('${PressureGauge._maxKpa.toStringAsFixed(0)} kPa', center.dx + radius);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}
