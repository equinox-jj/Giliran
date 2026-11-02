import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/themes/app_motion.dart';

/// Shakes [child] horizontally each time [trigger] changes (wrong code or
/// PIN). Skipped under reduced motion.
class Shake extends StatefulWidget {
  const Shake({
    super.key,
    required this.trigger,
    required this.child,
    this.distance = 8,
    this.oscillations = 2,
    this.duration = const Duration(milliseconds: 360),
  });

  final Object? trigger;
  final Widget child;
  final double distance;
  final int oscillations;
  final Duration duration;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !AppMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final v = _controller.value;
      final dx = math.sin(v * math.pi * 2 * widget.oscillations) * widget.distance * (1 - v);
      return Transform.translate(
        offset: Offset(dx, 0),
        child: child,
      );
    },
    child: widget.child,
  );
}
