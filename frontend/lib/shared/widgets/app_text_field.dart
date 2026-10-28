import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';

/// Tikar text input: label above (`caption`/600), 56-high field with a 1.5 px
/// `border.strong`, helper or error below. Focus = 2 px ink border; error =
/// 2 px bata border + `WarningCircle` message. Map API `422` `errors[].field`
/// straight to [errorText].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.sentences,
    this.prefix,
    this.suffix,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;

  /// Leading widget inside the field (e.g. the +62 chip or the Rp prefix).
  final Widget? prefix;

  /// Trailing widget inside the field (clear button, calendar icon).
  final Widget? suffix;

  /// Overrides the value style (default `bodyLg`).
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      style: (style ?? t.bodyLg).copyWith(
        color: enabled ? c.textPrimary : c.textTertiary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        // An empty error widget switches to the error border; the message is
        // rendered below with its icon.
        error: hasError ? const SizedBox.shrink() : null,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpace.s3,
                  end: AppSpace.s2,
                ),
                child: prefix,
              ),
        prefixIconConstraints: const BoxConstraints(minHeight: AppSizes.inputH),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.tapMin,
          minHeight: AppSizes.tapMin,
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: t.caption.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          field,
          if (hasError || helper != null) ...[
            const SizedBox(height: 6),
            FieldMessage(
              text: hasError ? errorText! : helper!,
              isError: hasError,
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper or error line under a field. Errors get a `WarningCircle` and are
/// announced as a live region.
class FieldMessage extends StatelessWidget {
  const FieldMessage({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = isError ? c.rejected.fg : c.textSecondary;
    return Semantics(
      liveRegion: isError,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError) ...[
            AppIcon(
              AppIcons.warningCircle,
              size: AppSizes.iconSm,
              color: color,
            ),
            const SizedBox(width: AppSpace.s1),
          ],
          Expanded(
            child: Text(text, style: t.caption.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Small 48-hit clear button for field suffixes.
class FieldClearButton extends StatelessWidget {
  const FieldClearButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Hapus isian',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: AppSizes.tapMin,
        child: Center(
          child: AppIcon(
            AppIcons.xCircleFill,
            size: AppSizes.iconMd,
            color: context.colors.textTertiary,
          ),
        ),
      ),
    ),
  );
}
