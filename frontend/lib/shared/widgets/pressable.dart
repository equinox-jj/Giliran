import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// Shared press feedback for Tikar controls: scale 0.97 + a 6% tint over
/// [shape] (darkens in light, lightens in dark), and a 2 px focus ring 2 px
/// outside the shape for keyboard and switch access.
///
/// [hitPadding] grows the tappable area around the visual (e.g. a 44 circle
/// with a 48 hit area) without moving the press and focus visuals.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.shape = AppShapes.pill,
    this.hitPadding = EdgeInsets.zero,
    this.semanticLabel,
    this.isButton = true,
    this.selected,
    this.tint = true,
    this.scale = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final ShapeBorder shape;
  final EdgeInsets hitPadding;
  final String? semanticLabel;
  final bool isButton;
  final bool? selected;
  final bool tint;
  final bool scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AppMotion.reduced(context);
    final pressed = _pressed && _enabled;

    Widget visual = CustomPaint(
      foregroundPainter: _PressPainter(
        shape: widget.shape,
        tint: widget.tint && pressed
            ? c.textPrimary.withValues(alpha: 0.06)
            : null,
        focus: _focused ? c.focus : null,
        textDirection: Directionality.of(context),
      ),
      child: widget.child,
    );

    if (widget.scale) {
      visual = AnimatedScale(
        scale: pressed ? AppMotion.pressScale : 1,
        duration: reduced ? Duration.zero : AppMotion.quick,
        curve: AppMotion.quickCurve,
        child: visual,
      );
    }

    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onLongPressStart: widget.onLongPressStart,
          onLongPressEnd: widget.onLongPressEnd,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          child: Padding(padding: widget.hitPadding, child: visual),
        ),
      ),
    );
  }
}

class _PressPainter extends CustomPainter {
  _PressPainter({
    required this.shape,
    required this.tint,
    required this.focus,
    required this.textDirection,
  });

  final ShapeBorder shape;
  final Color? tint;
  final Color? focus;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (tint != null) {
      canvas.drawPath(
        shape.getOuterPath(rect, textDirection: textDirection),
        Paint()..color = tint!,
      );
    }
    if (focus != null) {
      // 2 px ring, 2 px outside the shape: inflate by offset + half stroke.
      canvas.drawPath(
        shape.getOuterPath(rect.inflate(3), textDirection: textDirection),
        Paint()
          ..color = focus!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PressPainter old) =>
      old.tint != tint || old.focus != focus || old.shape != shape;
}
