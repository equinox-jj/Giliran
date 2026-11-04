import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/themes/themes.dart';

/// The winner reveal on the result screen (Tikar §13): the slip unrolls
/// (300 ms), the winner fades in, then the ticket rises (360 ms,
/// `motion.emphasis`), 900 ms in all with a heavy haptic at the reveal.
/// With [play] off (a later visit) everything is shown at once; with reduced
/// motion it is one 120 ms fade, and the haptic still fires.
class const RevealSequence({
  super.key,
  required final bool play,
  required final Widget slip,
  required final Widget winner,
  required final Widget ticket,
}) extends StatefulWidget {
  @override
  State<RevealSequence> createState() => _RevealSequenceState();
}

class _RevealSequenceState() extends State<RevealSequence> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _haptic;
  var _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.reveal, value: widget.play ? 0 : 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
    if (!widget.play || _controller.isAnimating || _controller.isCompleted) return;
    _controller.duration = _reduced ? AppMotion.quick : AppMotion.reveal;
    unawaited(_controller.forward());
    _haptic = Timer(
      _reduced ? Duration.zero : const Duration(milliseconds: 300),
      () => unawaited(HapticFeedback.heavyImpact()),
    );
  }

  @override
  void dispose() {
    _haptic?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) {
      return FadeTransition(
        opacity: _controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [widget.slip, widget.winner, widget.ticket],
        ),
      );
    }
    final unroll = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 1 / 3, curve: Curves.easeOut),
    );
    final appear = CurvedAnimation(
      parent: _controller,
      curve: const Interval(1 / 3, 0.6, curve: Curves.easeOut),
    );
    final rise = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1, curve: AppMotion.emphasized),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScaleTransition(scale: unroll, alignment: Alignment.topCenter, child: widget.slip),
        FadeTransition(
          opacity: appear,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(appear), child: widget.winner),
        ),
        FadeTransition(
          opacity: rise,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(rise),
            child: widget.ticket,
          ),
        ),
      ],
    );
  }
}
