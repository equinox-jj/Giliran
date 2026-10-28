import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'shake.dart';

/// Six code boxes (48 × 56) driven by ONE hidden text field, so paste,
/// one-time-code autofill and screen readers treat the code as one value
/// ("Kode 6 digit"). Auto-submits on the last digit.
///
/// Set [error] to true after `otp_invalid`: the boxes turn bata, shake and
/// clear. Set [checking] while verifying: boxes dim and input is disabled.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.onCompleted,
    this.controller,
    this.length = 6,
    this.onChanged,
    this.error = false,
    this.checking = false,
    this.autofocus = true,
    this.semanticLabel = 'Kode 6 digit',
  });

  final ValueChanged<String> onCompleted;
  final TextEditingController? controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final bool error;
  final bool checking;
  final bool autofocus;
  final String semanticLabel;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
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
    final t = AppTextStyles.of(context);
    final text = _controller.text;
    final enabled = !widget.checking;

    Widget box(int i) {
      final filled = i < text.length;
      final current =
          _focus.hasFocus && i == text.length.clamp(0, widget.length - 1);
      final (Color color, double width) = widget.error
          ? (c.rejected.fg, AppStroke.strong)
          : current
          ? (c.textPrimary, AppStroke.strong)
          : (c.borderStrong, AppStroke.regular);
      return Container(
        width: AppSizes.otpBoxW,
        height: AppSizes.otpBoxH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color, width: width),
        ),
        child: Text(
          filled ? text[i] : '',
          style: t.amountLg.copyWith(color: c.textPrimary),
        ),
      );
    }

    final boxes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s2),
          box(i),
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
          SizedBox.square(
            dimension: AppSizes.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}
