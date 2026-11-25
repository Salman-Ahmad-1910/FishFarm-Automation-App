import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/history.dart';
import 'common_ui.dart';

const double _padLeft = 44;
const double _padRight = 10;
const double _padTop = 10;
const double _padBottom = 22;

/// Where the points sit inside the chart area.
class _Geometry {
  final List<HistoryPoint> points;
  final double width;
  final double height;
  late final double yMin;
  late final double yMax;
  late final int t0;
  late final int t1;

  _Geometry(this.points, this.width, this.height) {
    var lo = points.first.avg;
    var hi = points.first.avg;
    for (final p in points) {
      if (p.avg < lo) lo = p.avg;
      if (p.avg > hi) hi = p.avg;
    }
    if (hi - lo < 0.001) {
      lo -= 1;
      hi += 1;
    } else {
      final pad = (hi - lo) * 0.15;
      lo -= pad;
      hi += pad;
    }
    yMin = lo;
    yMax = hi;
    t0 = points.first.start.millisecondsSinceEpoch;
    t1 = points.last.start.millisecondsSinceEpoch;
  }

  double get plotWidth => width - _padLeft - _padRight;
  double get plotHeight => height - _padTop - _padBottom;

  double xAtTime(int ms) {
    if (t1 == t0) return _padLeft + plotWidth / 2;
    return _padLeft + (ms - t0) / (t1 - t0) * plotWidth;
  }

  double x(int index) => xAtTime(points[index].start.millisecondsSinceEpoch);

  double y(double value) =>
      _padTop + (1 - (value - yMin) / (yMax - yMin)) * plotHeight;

  int nearest(double dx) {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (x(i) - dx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }
}

/// Line chart of 6-hour averages. Touch or drag to read a value.
class HistoryLineChart extends StatefulWidget {
  final List<HistoryPoint> points;
  final Color color;
  final String unit;
  final double height;

  const HistoryLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.unit,
    this.height = 220,
  });

  @override
  State<HistoryLineChart> createState() => _HistoryLineChartState();
}

class _HistoryLineChartState extends State<HistoryLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant HistoryLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();

    final index = (_selected != null && _selected! < points.length)
        ? _selected!
        : points.length - 1;
    final p = points[index];
    final from = DateFormat('dd MMM, HH:mm').format(p.start.toLocal());
    final to = DateFormat('HH:mm').format(p.end.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(
              '${p.avg.toStringAsFixed(1)} ${widget.unit}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'average  $from - $to',
                style: const TextStyle(fontSize: 12, color: AppColors.label),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final geo =
                  _Geometry(points, constraints.maxWidth, widget.height);
              void pick(double dx) {
                final i = geo.nearest(dx);
                if (i != _selected) setState(() => _selected = i);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => pick(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _ChartPainter(
                    geo: geo,
                    color: widget.color,
                    selected: index,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final _Geometry geo;
  final Color color;
  final int selected;

  _ChartPainter({
    required this.geo,
    required this.color,
    required this.selected,
  });

  void _text(Canvas canvas, String text, double x, double y,
      {bool alignRight = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = x;
    if (alignRight) dx = x - tp.width;
    if (center) dx = x - tp.width / 2;
    tp.paint(canvas, Offset(dx, y - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = geo.points;

    // Grid and y labels.
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final value = geo.yMin + (geo.yMax - geo.yMin) * i / 4;
      final y = geo.y(value);
      canvas.drawLine(
          Offset(_padLeft, y), Offset(size.width - _padRight, y), grid);
      _text(canvas, value.toStringAsFixed(1), _padLeft - 6, y,
          alignRight: true);
    }

    // x labels: dates for long ranges, times for short ones.
    final spanHours = (geo.t1 - geo.t0) / 3600000;
    final fmt = spanHours < 36 ? DateFormat('HH:mm') : DateFormat('dd MMM');
    final labelCount = points.length < 4 ? points.length : 4;
    for (var i = 0; i < labelCount; i++) {
      final idx = labelCount == 1
          ? 0
          : ((points.length - 1) * i / (labelCount - 1)).round();
      _text(
        canvas,
        fmt.format(points[idx].start.toLocal()),
        geo.x(idx),
        size.height - _padBottom / 2 + 2,
        center: true,
      );
    }

    // Area and line.
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final px = geo.x(i);
      final py = geo.y(points[i].avg);
      if (i == 0) {
        line.moveTo(px, py);
      } else {
        line.lineTo(px, py);
      }
    }
    if (points.length > 1) {
      final area = Path.from(line)
        ..lineTo(geo.x(points.length - 1), _padTop + geo.plotHeight)
        ..lineTo(geo.x(0), _padTop + geo.plotHeight)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = color.withValues(alpha: 0.12),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Dots.
    final dot = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(geo.x(i), geo.y(points[i].avg)), 2.6, dot);
    }

    // Selected point.
    final sx = geo.x(selected);
    final sy = geo.y(points[selected].avg);
    canvas.drawLine(
      Offset(sx, _padTop),
      Offset(sx, _padTop + geo.plotHeight),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(sx, sy), 6, Paint()..color = AppColors.card);
    canvas.drawCircle(Offset(sx, sy), 4.5, dot);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.geo.points != geo.points ||
      old.selected != selected ||
      old.color != color ||
      old.geo.width != geo.width;
}
