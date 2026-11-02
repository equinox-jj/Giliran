import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/themes/themes.dart';
import '../app_button.dart';

/// Adaptive confirmation dialog: `CupertinoAlertDialog` on iOS, a Tikar-styled
/// dialog elsewhere, with identical copy. Resolves to true when confirmed.
///
/// Use [destructive] for removing members, closing groups, deleting the
/// account and signing out devices.
Future<bool> showAppDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  bool destructive = true,
}) async {
  final platform = Theme.of(context).platform;
  final isCupertino = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) {
      if (isCupertino) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: message == null ? null : Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              isDefaultAction: !destructive,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      }

      final c = context.colors;
      final t = AppTextStyles.of(context);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s6,
              AppSpace.s6,
              AppSpace.s4,
              AppSpace.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s2),
                  child: Text(
                    title,
                    style: t.title.copyWith(color: c.textPrimary),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.s2),
                    child: Text(
                      message,
                      style: t.body.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.s5),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpace.s2,
                  children: [
                    AppButton.ghost(
                      label: cancelLabel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    AppButton(
                      label: confirmLabel,
                      size: AppButtonSize.small,
                      variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.ink,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
