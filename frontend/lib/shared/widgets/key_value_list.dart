import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'app_toast.dart';
import 'section_header.dart';

/// One row of a [KeyValueList].
class const KeyValueItem(
  final String label,
  final String value, {

  /// Codes and hashes in JetBrains Mono.
  final bool mono = false,

  /// Wraps the value below the label at full width (hashes, seeds, links).
  final bool long = false,

  /// Adds a "Salin" text button that copies the value without spaces.
  final bool copyable = false,

  /// Replaces the value text (a status chip, an amount span).
  final Widget? valueWidget,
}) {}

/// Label/value rows inside a `radius.md` card with hairlines between rows.
class const KeyValueList({
  super.key,
  required final List<KeyValueItem> items,

  /// Card fill (default `bg.surface`).
  final Color? color,

  /// Values in w600 instead of w500 (Create group's "Periksa lagi").
  final bool strongValues = false,

  /// A last row under a hairline, such as a link back to an earlier step.
  final Widget? footer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      decoration: ShapeDecoration(
        color: color ?? c.surface,
        shape: AppShapes.squircle(AppRadius.md),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: c.hairline),
            _KeyValueRow(items[i], strong: strongValues),
          ],
          if (footer case final footer?) ...[
            Divider(color: c.hairline),
            footer,
          ],
        ],
      ),
    );
  }
}

class const _KeyValueRow(final KeyValueItem item, {required final bool strong}) extends StatelessWidget {
  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.value.replaceAll(' ', '')));
    HapticFeedback.lightImpact();
    showAppToast(context, '${item.label} disalin');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final labelText = Text(
      item.label,
      style: t.caption.copyWith(color: c.textTertiary),
    );
    final valueStyle = item.mono
        ? t.mono.copyWith(color: c.textPrimary)
        : t.body.copyWith(color: c.textPrimary, fontWeight: strong ? FontWeight.w600 : FontWeight.w500);
    final value = item.valueWidget ?? Text(item.value, style: valueStyle);
    final copy = item.copyable ? AppTextButton(label: 'Salin', onPressed: () => _copy(context)) : null;

    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: item.long
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: labelText),
                        ?copy,
                      ],
                    ),
                    const SizedBox(height: AppSpace.s1),
                    value,
                  ],
                )
              : Row(
                  children: [
                    labelText,
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: DefaultTextStyle.merge(
                          textAlign: TextAlign.end,
                          child: value,
                        ),
                      ),
                    ),
                    if (copy != null) ...[
                      const SizedBox(width: AppSpace.s2),
                      copy,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
