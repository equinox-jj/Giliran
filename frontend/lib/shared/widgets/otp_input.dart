import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'shake.dart';

/// Six code boxes (48 × 58, spread across the width and shrinking to fit
/// narrow screens) driven by ONE hidden text field, so paste,
/// one-time-code autofill and screen readers treat the code as one value
/// ("Kode 6 digit"). Auto-submits on the last digit.
///
/// Set [error] to true after `otp_invalid`: the boxes turn bata, shake and
/// clear. Set [checking] while verifying: boxes dim and input is disabled.
class const OtpInput({
  super.key,
  required final ValueChanged<String> onCompleted,
  final TextEditingController? controller,
  final int length = 6,
  final ValueChanged<String>? onChanged,
  final bool error = false,
  final bool checking = false,
  final bool autofocus = true,
  final String semanticLabel = 'Kode 6 digit',
}) extends StatefulWidget {
  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState() extends State<OtpInput> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final _focus = FocusNode();
  int _shakes = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    if (widget.error && !old.error) {
      _shakes++;
      _controller.clear();
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    setState(() {});
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length && !widget.checking) {
      widget.onCompleted(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = _controller.text;
    final enabled = !widget.checking;

    // Boxes keep 48 × 58 and spread across the width; on narrow screens
    // they shrink evenly (same ratio) so six of them never overflow.
    final boxes = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s1),
          Flexible(
            child: _OtpBox(
              digit: i < text.length ? text[i] : '',
              current: _focus.hasFocus && i == text.length.clamp(0, widget.length - 1),
              error: widget.error,
            ),
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Shake(
          trigger: _shakes,
          child: AnimatedOpacity(
            opacity: widget.checking ? 0.5 : 1,
            duration: AppMotion.quick,
            child: Stack(
              children: [
                ExcludeSemantics(child: boxes),
                Positioned.fill(
                  child: Semantics(
                    label: widget.semanticLabel,
                    textField: true,
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        enabled: enabled,
                        autofocus: widget.autofocus,
                        showCursor: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(widget.length),
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.checking) ...[
          const SizedBox(height: AppSpace.s3),
          // Its own layer, so the spinner's frames don't repaint the boxes.
          RepaintBoundary(
            child: SizedBox.square(
              dimension: AppSizes.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One code box, at most 48 × 58. [current] marks where the next digit
/// lands: a 2 px ink border with a blinking caret while it is empty.
class const _OtpBox({
  required final String digit,
  required final bool current,
  required final bool error,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color borderColor, double stroke) = error
        ? (c.rejected.fg, AppStroke.strong)
        : current
        ? (c.textPrimary, AppStroke.strong)
        : digit.isNotEmpty
        ? (c.borderStrong, AppStroke.regular)
        : (c.hairline, AppStroke.regular);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.otpBoxW),
      child: AspectRatio(
        aspectRatio: AppSizes.otpBoxW / AppSizes.otpBoxH,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: borderColor, width: stroke),
          ),
          child: current && digit.isEmpty && !error
              ? const _Caret()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    digit,
                    style: AppTextStyles.of(context).amountLg.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The 2 × 28 blinking caret in the current empty box. Stays on when the
/// platform asks for reduced motion.
class const _Caret() extends StatefulWidget {
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState() extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _blink
        ..stop()
        ..value = 1;
    } else if (!_blink.isAnimating) {
      _blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    // A hard on/off blink rather than a fade.
    opacity: _blink.drive(CurveTween(curve: const Threshold(0.5))),
    child: Container(width: 2, height: 28, color: context.colors.textPrimary),
  );
}
