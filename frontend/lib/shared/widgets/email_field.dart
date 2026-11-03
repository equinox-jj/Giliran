import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'app_text_field.dart';

/// Email field for sign-in and change email: an envelope icon in front and a
/// clear button once there is text. No autocorrect or capitalization; checks
/// a basic `name@domain` shape after the user leaves the field or submits.
/// The server is the final judge.
class const EmailField({
  super.key,
  required final TextEditingController controller,
  final String label = 'Email',
  final String hint = 'nama@email.com',
  final String? helper,

  /// Server-side error; takes precedence over the inline format check.
  final String? errorText,

  /// Called with the normalized (trimmed, lowercased) address.
  final ValueChanged<String>? onSubmitted,
  final bool autofocus = false,
  final TextInputAction textInputAction = TextInputAction.done,
}) extends StatefulWidget {
  static final _shape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String normalize(String input) => input.trim().toLowerCase();

  /// Whether [input], once normalized, looks like an email address. Checks the
  /// shape only, not that the address exists.
  static bool isValidShape(String input) => _shape.hasMatch(normalize(input));

  static const formatError = 'Format email belum benar';

  @override
  State<EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState() extends State<EmailField> {
  final _focus = FocusNode();
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && widget.controller.text.isNotEmpty) {
        setState(() => _checked = true);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _onCleared() {
    widget.controller.clear();
    setState(() => _checked = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final inline = _checked && text.isNotEmpty && !EmailField.isValidShape(text) ? EmailField.formatError : null;

    return AppTextField(
      controller: widget.controller,
      focusNode: _focus,
      label: widget.label,
      hint: widget.hint,
      helper: widget.helper,
      errorText: widget.errorText ?? inline,
      keyboardType: TextInputType.emailAddress,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      autofocus: widget.autofocus,
      prefix: AppIcon(
        AppIcons.envelopeSimple,
        size: AppSizes.iconMd,
        color: context.colors.textTertiary,
      ),
      suffix: _ClearButton(controller: widget.controller, onCleared: _onCleared),
      onChanged: (_) {
        if (_checked) setState(() {});
      },
      onSubmitted: (value) {
        setState(() => _checked = true);
        final normalized = EmailField.normalize(value);
        if (EmailField.isValidShape(normalized)) {
          widget.onSubmitted?.call(normalized);
        }
      },
    );
  }
}

/// The clear button, shown only while the field has text.
class const _ClearButton({
  required final TextEditingController controller,
  required final VoidCallback onCleared,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) =>
          value.text.isEmpty ? const SizedBox.shrink() : FieldClearButton(onPressed: onCleared),
    );
  }
}
