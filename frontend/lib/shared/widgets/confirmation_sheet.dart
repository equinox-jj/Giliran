import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'adaptive/app_sheet.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'check_row.dart';
import 'key_value_list.dart';

/// Opens a confirmation sheet for actions with consequences that aren't
/// destructive (approve payment, mark paid, incomplete draw, record payout,
/// start group). Resolves to true when confirmed.
///
/// With [consentLabel] the primary button stays disabled until the consent
/// row is checked.
Future<bool> showConfirmationSheet(
  BuildContext context, {
  required String icon,
  required String title,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  List<KeyValueItem> summary = const [],
  String? consentLabel,
  Color? toneColor,
}) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (context) => _ConfirmationSheet(
      icon: icon,
      title: title,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      summary: summary,
      consentLabel: consentLabel,
      toneColor: toneColor,
    ),
  );
  return result ?? false;
}

class _ConfirmationSheet extends StatefulWidget {
  const _ConfirmationSheet({
    required this.icon,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.summary,
    required this.consentLabel,
    required this.toneColor,
  });

  final String icon;
  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final List<KeyValueItem> summary;
  final String? consentLabel;
  final Color? toneColor;

  @override
  State<_ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends State<_ConfirmationSheet> {
  bool _consent = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final needsConsent = widget.consentLabel != null;

    return AppSheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.toneColor ?? c.hero,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIcon(widget.icon, size: 26, color: c.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Semantics(
            header: true,
            child: Text(
              widget.title,
              style: t.titleLg.copyWith(color: c.textPrimary),
            ),
          ),
          if (widget.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s4),
            KeyValueList(items: widget.summary, color: c.subtle),
          ],
          if (needsConsent) ...[
            const SizedBox(height: AppSpace.s3),
            CheckRow(
              label: widget.consentLabel!,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v),
            ),
          ],
          const SizedBox(height: AppSpace.s5),
          AppButton(
            label: widget.confirmLabel,
            block: true,
            onPressed: !needsConsent || _consent ? () => Navigator.of(context).pop(true) : null,
          ),
          const SizedBox(height: AppSpace.s1),
          AppButton.ghost(
            label: widget.cancelLabel,
            block: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
