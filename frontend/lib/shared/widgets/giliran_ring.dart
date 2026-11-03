import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';

/// Ring diameters from Tikar §9.1: cards, rows, the hero and the tablet hero.
enum GiliranRingSize(final double diameter, final double stroke) {
  s48(48, 4),
  s64(64, 5),
  s96(96, 6),
  s120(120, 7);

  bool get isSmall => this == GiliranRingSize.s48 || this == GiliranRingSize.s64;
}

/// The Giliran Ring (Tikar §9.1): anything counted, such as payments paid,
/// the cycle's period or a draft group's filled slots.
///
/// Progress runs clockwise from 12 o'clock in [color] (the group tone
/// accent); [pending] continues the arc with the tikar hatch. A full ring
/// turns pandan and shows a check. Value changes animate over
/// [AppMotion.emphasis], or snap with reduced motion.
class const GiliranRing({
  super.key,
  required final int value,
  required final int total,
  final int pending = 0,
  required final GiliranRingSize size,

  /// Small line under the numbers on the 96 and 120 rings ("sudah bayar").
  final String? caption,

  /// Progress color; defaults to `text.primary`.
  final Color? color,

  /// Read by screen readers instead of the numbers, e.g. "8 dari 10 anggota
  /// sudah bayar, 1 menunggu dicek".
  required final String semanticsLabel,
}) extends StatelessWidget {
  bool get _complete => total > 0 && value >= total;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size.diameter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: reduceMotion ? Duration.zero : AppMotion.emphasis,
            curve: AppMotion.emphasized,
            builder: (context, animated, _) => _RingFace(
              animatedValue: animated,
              total: total,
              pending: pending,
              size: size,
              caption: caption,
              color: color,
              complete: _complete,
            ),
          ),
        ),
      ),
    );
  }
}

class const _RingFace({
  required final double animatedValue,
  required final int total,
  required final int pending,
  required final GiliranRingSize size,
  required final String? caption,
  required final Color? color,
  required final bool complete,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progressColor = complete ? c.paid.fg : (color ?? c.textPrimary);
    return CustomPaint(
      painter: _RingPainter(
        progress: total == 0 ? 0 : (animatedValue / total).clamp(0, 1),
        pending: total == 0 ? 0 : (pending / total).clamp(0, 1),
        stroke: size.stroke,
        track: c.textPrimary.withValues(alpha: 0.12),
        progressColor: progressColor,
        pendingColor: c.pending.fg,
      ),
      child: Center(
        child: complete
            ? AppIcon(
                AppIcons.checkBold,
                size: size.isSmall ? AppSizes.iconMd : AppSizes.iconXl,
                color: progressColor,
              )
            : _RingLabel(
                value: animatedValue.round(),
                total: total,
                size: size,
                caption: caption,
              ),
      ),
    );
  }
}

class const _RingLabel({
  required final int value,
  required final int total,
  required final GiliranRingSize size,
  required final String? caption,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    const tnum = AppTextStyles.tabularFigures;
    if (size.isSmall) {
      return Text(
        '$value/$total',
        maxLines: 1,
        style: t.caption.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
          fontFeatures: tnum,
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$value',
                  style: t.titleLg.copyWith(fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
                TextSpan(
                  text: '/$total',
                  style: t.body.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            style: TextStyle(fontFeatures: tnum),
          ),
          if (caption != null)
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: t.micro.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

class const _RingPainter({
  required final double progress,
  required final double pending,
  required final double stroke,
  required final Color track,
  required final Color progressColor,
  required final Color pendingColor,
}) extends CustomPainter {
  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, line..color = track);

    final sweep = 2 * math.pi * progress;
    final pendingSweep = math.min(2 * math.pi * pending, 2 * math.pi - sweep);
    if (pendingSweep > 0) _paintPending(canvas, size, center, radius, _start + sweep, pendingSweep);
    if (sweep > 0) {
      canvas.drawArc(rect, _start, sweep, false, line..color = progressColor);
    }
  }

  /// The pending segment: the ring band clipped to the pending wedge, filled
  /// with 45° hatch lines (the tikar hatch at ring scale).
  void _paintPending(Canvas canvas, Size size, Offset center, double radius, double from, double sweep) {
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: radius + stroke / 2))
      ..addOval(Rect.fromCircle(center: center, radius: radius - stroke / 2));
    final outer = radius + stroke;
    final wedge = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: outer), from, sweep, false)
      ..close();
    final clip = Path.combine(PathOperation.intersect, band, wedge);
    canvas
      ..save()
      ..clipPath(clip)
      ..drawPaint(Paint()..color = pendingColor.withValues(alpha: 0.12));
    final hatch = Paint()
      ..color = pendingColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    const step = 4.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.pending != pending ||
      old.stroke != stroke ||
      old.track != track ||
      old.progressColor != progressColor ||
      old.pendingColor != pendingColor;
}
