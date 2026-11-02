import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import '../../core/utils/phone_formatter.dart';
import 'app_text_field.dart';

/// Phone field with a fixed +62 segment. Accepts 08…, 62…, +62… (typed or
/// pasted) and keeps only the local part. Read the value with
/// [PhoneField.e164]. Used for guest numbers and the optional WhatsApp number,
/// never for sign-in.
class const PhoneField({
  super.key,
  required final TextEditingController controller,
  final String label = 'Nomor WhatsApp',

  /// The lighter note after [label].
  final String? labelHint = '(opsional)',
  final String? helper,

  /// An `AppIcons` asset in front of [helper].
  final String? helperIcon,
  final String? errorText,
  final ValueChanged<String>? onChanged,
  final TextInputAction textInputAction = TextInputAction.done,
}) extends StatefulWidget {
  /// "812 3456 7890" -> "+6281234567890"; null when empty.
  static String? e164(String text) => PhoneFormatter.normalize(text);

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState() extends State<PhoneField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      labelHint: widget.labelHint,
      helper: widget.helper,
      helperIcon: widget.helperIcon,
      errorText: widget.errorText,
      hint: '812-3456-7890',
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: const [_LocalPhoneFormatter()],
      onChanged: widget.onChanged,
      prefixFlush: true,
      prefix: Padding(
        // Inset by the focus stroke so the segment never covers the border.
        padding: const EdgeInsetsDirectional.only(
          start: AppStroke.strong,
          top: AppStroke.strong,
          bottom: AppStroke.strong,
          end: AppSpace.s3,
        ),
        child: SizedBox(
          height: AppSizes.inputH - 2 * AppStroke.strong,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.subtle,
                  borderRadius: const BorderRadiusDirectional.horizontal(
                    start: Radius.circular(AppRadius.sm - AppStroke.strong),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+62',
                  style: t.bodyLg.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                ),
              ),
              Container(width: 1, color: c.hairline),
            ],
          ),
        ),
      ),
      suffix: widget.controller.text.isEmpty
          ? null
          : FieldClearButton(
              onPressed: () {
                widget.controller.clear();
                widget.onChanged?.call('');
              },
            ),
    );
  }
}

/// Strips everything but digits and a leading 0 / 62 country prefix.
class const _LocalPhoneFormatter() extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final e164 = PhoneFormatter.normalize(newValue.text);
    var local = e164 == null ? '' : PhoneFormatter.localPart(e164);
    if (local.length > 13) local = local.substring(0, 13);
    return TextEditingValue(
      text: local,
      selection: TextSelection.collapsed(offset: local.length),
    );
  }
}
