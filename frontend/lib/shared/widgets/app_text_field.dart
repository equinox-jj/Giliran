import '../../core/l10n/l10n.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';

/// Tikar text input: label above (`caption`/600), 56-high field with a 1.5 px
/// `border.strong`, helper or error below. Focus = 2 px ink border; error =
/// 2 px bata border + `WarningCircle` message. Map API `422` `errors[].field`
/// straight to [errorText].
class const AppTextField({
  super.key,
  final TextEditingController? controller,
  final FocusNode? focusNode,
  final String? label,

  /// A lighter note after [label], such as "(opsional)".
  final String? labelHint,
  final String? hint,
  final String? helper,

  /// An `AppIcons` asset in front of [helper].
  final String? helperIcon,

  /// Right-aligned under the field, such as the "22/50" character count.
  final String? counter,
  final String? errorText,
  final TextInputType? keyboardType,
  final TextInputAction? textInputAction,
  final Iterable<String>? autofillHints,
  final List<TextInputFormatter>? inputFormatters,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
  final VoidCallback? onTap,
  final bool obscureText = false,
  final bool enabled = true,
  final bool readOnly = false,
  final bool autofocus = false,
  final bool autocorrect = true,
  final bool enableSuggestions = true,
  final TextCapitalization textCapitalization = TextCapitalization.sentences,

  /// Leading widget inside the field (e.g. the +62 segment or the Rp prefix).
  final Widget? prefix,

  /// Lays [prefix] against the field's start edge with no padding, for a
  /// segment that fills the field's height (the +62 of `PhoneField`).
  final bool prefixFlush = false,

  /// Trailing widget inside the field (clear button, calendar icon).
  final Widget? suffix,

  /// Overrides the value style (default `bodyLg`).
  final TextStyle? style,
  final int? maxLines = 1,
  final int? minLines,
  final String? semanticLabel,
}) extends StatelessWidget {
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
      // The default iOS menu (`SystemContextMenu`) asserts "Attempted to show
      // while another instance was still visible" when the keyboard resizes
      // the view, so use the Flutter-drawn toolbar instead.
      contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.editableText(
        editableTextState: editableTextState,
      ),
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      style: (style ?? t.bodyLg).copyWith(
        color: enabled ? c.textPrimary : c.textTertiary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        // Match the value style so a custom-sized hint sits on the same line.
        hintStyle: style?.copyWith(color: c.textTertiary),
        // An empty error widget switches to the error border; the message is
        // rendered below with its icon.
        error: hasError ? const SizedBox.shrink() : null,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: EdgeInsetsDirectional.only(
                  start: prefixFlush ? 0 : AppSpace.s3,
                  end: prefixFlush ? 0 : AppSpace.s2,
                ),
                // The decorator forces the prefix to the full field height;
                // center it and keep it at its own width.
                child: Center(widthFactor: 1, heightFactor: 1, child: prefix),
              ),
        prefixIconConstraints: const BoxConstraints(minHeight: AppSizes.inputH),
        // The 48 min constraints below would stretch a bare icon to 48;
        // center it so it keeps its own size inside the tap target.
        suffixIcon: suffix == null ? null : Center(widthFactor: 1, heightFactor: 1, child: suffix),
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
            Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (labelHint case final labelHint?)
                    TextSpan(
                      text: ' $labelHint',
                      style: TextStyle(color: c.textTertiary, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
              style: t.caption.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          field,
          if (hasError || helper != null || counter != null) ...[
            const SizedBox(height: 6),
            FieldMessage(
              text: hasError ? errorText! : helper ?? '',
              isError: hasError,
              icon: hasError ? null : helperIcon,
              trailing: counter,
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper or error line under a field. Errors get a `WarningCircle` and are
/// announced as a live region; a helper may carry its own [icon]. [trailing]
/// sits at the end in tabular figures (the character count).
class const FieldMessage({
  super.key,
  required final String text,
  final bool isError = false,
  final String? icon,
  final String? trailing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = isError ? c.rejected.fg : c.textSecondary;
    final icon = isError ? AppIcons.warningCircle : this.icon;
    return Semantics(
      liveRegion: isError,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AppIcon(icon, size: AppSizes.iconSm, color: color),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(text, style: t.caption.copyWith(color: color)),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: AppSpace.s2),
            Text(
              trailing,
              style: t.caption.copyWith(
                color: c.textTertiary,
                fontFeatures: AppTextStyles.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small 48-hit clear button for field suffixes.
class const FieldClearButton({super.key, required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.widgetClearField,
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
