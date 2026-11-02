import 'package:material_ui/material_ui.dart';

import 'app_text_field.dart';

/// Email field for sign-in and change email. No autocorrect or
/// capitalization; checks a basic `name@domain` shape after the user leaves
/// the field or submits. The server is the final judge.
class EmailField extends StatefulWidget {
  const EmailField({
    super.key,
    required this.controller,
    this.label = 'Email',
    this.hint = 'nama@email.com',
    this.helper,
    this.errorText,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;

  /// Server-side error; takes precedence over the inline format check.
  final String? errorText;

  /// Called with the normalized (trimmed, lowercased) address.
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction textInputAction;

  static final _shape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String normalize(String input) => input.trim().toLowerCase();

  /// Whether [input], once normalized, looks like an email address. Checks the
  /// shape only, not that the address exists.
  static bool isValidShape(String input) => _shape.hasMatch(normalize(input));

  static const formatError = 'Format email belum benar';

  @override
  State<EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends State<EmailField> {
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

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final inline = _checked && text.isNotEmpty && !EmailField.isValidShape(text)
        ? EmailField.formatError
        : null;

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
