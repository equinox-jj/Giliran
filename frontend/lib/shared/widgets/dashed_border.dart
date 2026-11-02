import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/themes/app_spacing.dart';

/// Paints a dashed outline (dash 4, gap 3) around [child]. Used for unpaid
/// and upcoming states, guest avatar rings, empty PIN dots and empty slots.
class DashedBorder extends StatelessWidget {
  const new({
    super.key,
    required this.color,
    this.child,
    this.radius,
    this.circle = false,
    this.strokeWidth = AppStroke.regular,
  });

  /// Circular dashed ring.
  const new circle({
    super.key,
    required this.color,
    this.child,
    this.strokeWidth = AppStroke.regular,
  }) : circle = true,
       radius = null;

  final Color color;
  final Widget? child;

  /// Corner radius for a rounded rectangle; null with [circle] false = stadium.
  final double? radius;
  final bool circle;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: DashedBorderPainter(
      color: color,
      radius: radius,
      circle: circle,
      strokeWidth: strokeWidth,
    ),
    child: child,
  );
}

/// Paints a dashed outline around a rounded rectangle, or around a circle when
/// [circle] is `true`.
class const DashedBorderPainter({
  required final Color color,
  final double? radius,
  final bool circle = false,
  final double strokeWidth = AppStroke.regular,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      final r = radius ?? rect.shortestSide / 2;
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + AppStroke.dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + AppStroke.dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.circle != circle || old.strokeWidth != strokeWidth;
}
