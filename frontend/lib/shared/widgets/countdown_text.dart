import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import '../../core/utils/date_formatter.dart';

/// Countdown to [until], ticking every second while mounted. Screen readers
/// get a label that updates once a minute.
///
/// Inline: "Kocokan dalam 2 hari 04:12:30"; on the day itself, "Hari ini,
/// 19.30" (unless [showTimeOnSameDay] is off). Lock: a large "14:52" with a
/// caption (PIN locked, resend wait).
class CountdownText extends StatefulWidget {
  const new({
    super.key,
    required this.until,
    this.prefix = '',
    this.showTimeOnSameDay = true,
    this.onFinished,
  }) : lock = false,
       caption = null;

  const new lock({
    super.key,
    required this.until,
    this.caption = 'Coba lagi setelah waktu habis',
    this.onFinished,
  }) : lock = true,
       prefix = '',
       showTimeOnSameDay = false;

  final DateTime until;
  final String prefix;

  /// Whether the inline countdown switches to "Hari ini, 19.30" when [until]
  /// is today. Off for short waits (a `429` retry), where the ticking
  /// countdown is the message.
  final bool showTimeOnSameDay;
  final bool lock;
  final String? caption;
  final VoidCallback? onFinished;

  /// Formats [d] as `HH:mm:ss`, with a leading day count (`2 hari 04:12:30`) when
  /// it is a day or more.
  @visibleForTesting
  static String formatInline(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final days = d.inDays;
    final clock = '${two(d.inHours % 24)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return days > 0 ? '$days hari $clock' : clock;
  }

  /// Formats [d] as `mm:ss`. Minutes are not wrapped at 60.
  @visibleForTesting
  static String formatLock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = d.inMinutes;
    return '${two(minutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState() extends State<CountdownText> {
  Timer? _timer;
  late Duration _left = _remaining();
  bool _finished = false;

  Duration _remaining() {
    final d = widget.until.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left = _remaining());
      if (_left == Duration.zero && !_finished) {
        _finished = true;
        _timer?.cancel();
        widget.onFinished?.call();
      }
    });
  }

  @override
  void didUpdateWidget(CountdownText old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) {
      _finished = false;
      _left = _remaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final minutesLeft = (_left.inSeconds / 60).ceil();

    if (widget.lock) {
      return Semantics(
        label: '$minutesLeft menit lagi. ${widget.caption ?? ''}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CountdownText.formatLock(_left),
              style: t.amountLg.copyWith(color: c.textPrimary),
            ),
            if (widget.caption != null)
              Text(
                widget.caption!,
                style: t.caption.copyWith(color: c.textSecondary),
              ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final sameDay =
        widget.showTimeOnSameDay &&
        now.year == widget.until.year &&
        now.month == widget.until.month &&
        now.day == widget.until.day;
    final text = sameDay
        ? 'Hari ini, ${AppDate.time(widget.until)}'
        : '${widget.prefix}${CountdownText.formatInline(_left)}';

    return Semantics(
      label: sameDay ? text : '${widget.prefix}$minutesLeft menit lagi',
      excludeSemantics: true,
      child: Text(
        text,
        style: t.label.copyWith(
          color: c.textPrimary,
          fontFeatures: AppTextStyles.tabularFigures,
        ),
      ),
    );
  }
}
