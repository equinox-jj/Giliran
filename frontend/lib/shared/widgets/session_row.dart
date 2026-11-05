import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/date_formatter.dart';
import 'adaptive/app_dialog.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'status_chip.dart';

/// Session row (8.25): one signed-in device on Security. The current
/// device shows the "Perangkat ini" pill; others get a ghost "Keluarkan"
/// that confirms with an adaptive dialog before calling [onSignOut].
class const SessionRow({
  super.key,

  /// API `device_name`; null shows "Perangkat tanpa nama".
  required final String? deviceName,

  /// API `device_platform`: `android` or `ios`.
  final String? platform,
  final DateTime? lastActiveAt,
  final bool current = false,
  final VoidCallback? onSignOut,

  /// The clock for the relative time; defaults to now.
  final DateTime? now,
}) extends StatelessWidget {
  Future<void> _confirm(BuildContext context, String name) async {
    final l10n = context.l10n;
    final confirmed = await showAppDialog(
      context,
      title: l10n.sessionSignOutTitle(name),
      message: l10n.sessionSignOutMessage,
      confirmLabel: l10n.sessionSignOut,
      cancelLabel: l10n.commonCancel,
    );
    if (confirmed) onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final name = switch (deviceName?.trim()) {
      final name? when name.isNotEmpty => name,
      _ => l10n.sessionUnknownDevice,
    };
    final lastActive = lastActiveAt;

    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.rowH),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(color: c.subtle, shape: BoxShape.circle),
            alignment: Alignment.center,
            // There are no platform logos in the icon set yet, and the API
            // does not tell phones from tablets, so every device is a phone.
            child: AppIcon(AppIcons.deviceMobile, size: AppSizes.iconMd, color: c.textSecondary),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            // The name and status read as one; "Keluarkan" stays its own
            // action.
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: t.bodyLg.copyWith(color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (current)
                    StatusChip(ChipStatus.paid, label: l10n.sessionThisDevice)
                  else if (lastActive != null)
                    Text(
                      l10n.sessionActive(AppDate.smart(lastActive, now: now)),
                      style: t.caption.copyWith(color: c.textTertiary),
                    ),
                ],
              ),
            ),
          ),
          if (!current && onSignOut != null) ...[
            const SizedBox(width: AppSpace.s2),
            AppButton.ghost(
              label: l10n.sessionSignOut,
              size: AppButtonSize.small,
              semanticLabel: l10n.sessionSignOutSemantic(name),
              onPressed: () => _confirm(context, name),
            ),
          ],
        ],
      ),
    );
  }
}
