import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import '../../core/utils/input_formatters.dart';
import 'app_text_field.dart';

/// Rupiah amount field: `amountLg` digits, a fixed small "Rp" prefix and live
/// dot grouping. Read the value with [AmountField.parse].
class const AmountField({
  super.key,
  required final TextEditingController controller,
  final String? label,
  final String? helper,
  final String? errorText,

  /// Called with the parsed integer amount (null when empty).
  final ValueChanged<int?>? onChanged,
  final TextInputAction textInputAction = TextInputAction.done,
}) extends StatelessWidget {
  static int? parse(String text) => RupiahInputFormatter.parse(text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppTextStyles.of(context).amountLg;

    // The iOS number pad has no return key; the signed variant shows one,
    // and the formatter drops anything that isn't a digit.
    final keyboard = defaultTargetPlatform == TargetPlatform.iOS
        ? const TextInputType.numberWithOptions(signed: true)
        : TextInputType.number;

    return AppTextField(
      controller: controller,
      label: label,
      helper: helper,
      errorText: errorText,
      hint: '0',
      style: style,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      inputFormatters: const [RupiahInputFormatter()],
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (text) => onChanged?.call(parse(text)),
      prefix: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpace.s1),
        child: Text(
          'Rp',
          style: style.copyWith(
            fontSize: style.fontSize! * 0.55,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: c.textPrimary,
          ),
        ),
      ),
    );
  }
}
