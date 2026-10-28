import 'package:flutter/widgets.dart';

/// The tikar hatch: 45° lines, 2 px wide, 6 px apart, at 22% of [color].
/// Used only for "waiting" states, always with the hourglass icon and a word.
class TikarHatchPainter extends CustomPainter {
  const TikarHatchPainter(this.color, {this.background});

  final Color color;

  /// Optional fill painted under the lines.
  final Color? background;

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    const step = 8.0; // 2 px line + 6 px space
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TikarHatchPainter old) =>
      old.color != color || old.background != background;
}

/// Paints the tikar hatch behind [child], clipped to [borderRadius].
class TikarHatch extends StatelessWidget {
  const TikarHatch({
    super.key,
    required this.color,
    required this.child,
    this.background,
    this.borderRadius = BorderRadius.zero,
  });

  final Color color;
  final Widget child;

  /// Fill under the hatch; the child should then have no background itself.
  final Color? background;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: CustomPaint(
      painter: TikarHatchPainter(color, background: background),
      child: child,
    ),
  );
}
