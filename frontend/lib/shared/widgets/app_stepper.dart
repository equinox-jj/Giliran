import '../../core/l10n/l10n.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Whole numbers within a range (slots 2–50, reminder days 0–7): label left,
/// minus · editable value · plus right. Long-press repeats every 120 ms; at a
/// limit the button disables and a caption states the range. [helper] shows
/// the live consequence ("10 periode · selesai Agu 2027").
class const AppStepper({
  super.key,
  required final String label,
  required final int value,
  required final int min,
  required final int max,
  required final ValueChanged<int> onChanged,

  /// Used in the limit caption: "Maksimal 50 slot".
  final String? unit,
  final String? helper,
}) extends StatefulWidget {
  @override
  State<AppStepper> createState() => _AppStepperState();
}

class _AppStepperState() extends State<AppStepper> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();
  Timer? _repeat;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        // Typing replaces the value instead of splicing into it ("1|0" + 2
        // would read 120).
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      } else {
        _commit(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(AppStepper old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _current = 0;

  void _set(int v) {
    final next = v.clamp(widget.min, widget.max);
    _current = next;
    if (next != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(next);
    }
  }

  void _commit(String text) {
    final parsed = int.tryParse(text);
    _set(parsed ?? widget.value);
    _controller.text = '${(parsed ?? widget.value).clamp(widget.min, widget.max)}';
  }

  /// Pushes in-range values while typing so the helper and anything derived
  /// from the value (pot, end date) follow the digits. Out-of-range or
  /// partial input waits for [_commit] to clamp it.
  void _onTyped(String text) {
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
      _set(parsed);
    }
  }

  void _startRepeat(int delta) {
    _current = widget.value;
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final next = _current + delta;
      if (next < widget.min || next > widget.max) {
        _repeat?.cancel();
        return;
      }
      _set(next);
    });
  }

  void _stopRepeat() => _repeat?.cancel();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final atMin = widget.value <= widget.min;
    final atMax = widget.value >= widget.max;
    final unit = widget.unit == null ? '' : ' ${widget.unit}';
    final limit = atMax
        ? context.l10n.widgetStepperMax('${widget.max}$unit')
        : atMin
        ? context.l10n.widgetStepperMin('${widget.min}$unit')
        : null;
    final valueStyle = t.amountLg.copyWith(color: c.textPrimary);
    final valuePad = (AppSizes.tapMin - valueStyle.fontSize! * valueStyle.height!) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: t.bodyLg.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            _StepButton(
              icon: AppIcons.minusBold,
              label: context.l10n.widgetDecrease,
              onTap: !atMin ? () => _set(widget.value - 1) : null,
              onRepeatStart: !atMin ? () => _startRepeat(-1) : null,
              onRepeatEnd: _stopRepeat,
            ),
            const SizedBox(width: AppSpace.s1),
            SizedBox(
              width: 56,
              child: Semantics(
                label: widget.label,
                value: '${widget.value}',
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter('${widget.max}'.length),
                  ],
                  onChanged: _onTyped,
                  onSubmitted: _commit,
                  style: valueStyle,
                  // Equal top/bottom padding grows the one-line field to a
                  // 48 px tap target with the digits on the buttons'
                  // midline. A min-height constraint would grow it too but
                  // pins the text to the top, since textAlignVertical
                  // doesn't apply to a collapsed decoration. The empty
                  // constraints clear the theme's 56 px min height.
                  decoration: InputDecoration(
                    constraints: const BoxConstraints(),
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: valuePad),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s1),
            _StepButton(
              icon: AppIcons.plusBold,
              label: context.l10n.widgetIncrease,
              onTap: !atMax ? () => _set(widget.value + 1) : null,
              onRepeatStart: !atMax ? () => _startRepeat(1) : null,
              onRepeatEnd: _stopRepeat,
            ),
          ],
        ),
        if (limit != null || widget.helper != null) ...[
          const SizedBox(height: AppSpace.s1),
          Text(
            [?limit, ?widget.helper].join(' · '),
            style: t.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Round minus/plus button; long-press repeats via [onRepeatStart].
/// [onTap] null disables it.
class const _StepButton({
  required final String icon,
  required final String label,
  required final VoidCallback? onTap,
  required final VoidCallback? onRepeatStart,
  required final VoidCallback onRepeatEnd,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      onLongPressStart: enabled ? (_) => onRepeatStart?.call() : null,
      onLongPressEnd: enabled ? (_) => onRepeatEnd() : null,
      semanticLabel: label,
      shape: const CircleBorder(),
      hitPadding: const EdgeInsets.all(2),
      child: Container(
        width: AppSizes.circleButton,
        height: AppSizes.circleButton,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.hairline, width: AppStroke.regular),
        ),
        alignment: Alignment.center,
        child: AppIcon(
          icon,
          size: AppSizes.iconMd,
          color: enabled ? c.textPrimary : c.textTertiary,
        ),
      ),
    );
  }
}
