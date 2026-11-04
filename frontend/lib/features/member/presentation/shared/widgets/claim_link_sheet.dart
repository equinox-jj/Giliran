import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/share_service.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/claim_link.dart';
import '../../../domain/entities/member.dart';

/// Opens Guest claim link (S28) for [guest] with a fresh [link].
Future<void> showClaimLinkSheet(
  BuildContext context, {
  required Member guest,
  required ClaimLink link,
  required String groupName,
}) => showAppSheet<void>(
  context,
  builder: (_) => ClaimLinkSheet(guest: guest, link: link, groupName: groupName),
);

/// "Biar {name} pakai aplikasi": the claim link in a mono field with copy,
/// "Kirim lewat WhatsApp" (to the guest's phone when set) and the expiry.
class const ClaimLinkSheet({
  super.key,
  required final Member guest,
  required final ClaimLink link,
  required final String groupName,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final name = guest.displayName ?? '';
    final url = link.url ?? '';
    final expires = link.expiresAt;

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: url));
      await HapticFeedback.lightImpact();
      if (context.mounted) showAppToast(context, l10n.claimLinkCopied);
    }

    Future<void> send() => ref
        .read(shareServiceProvider)
        .openWhatsApp(
          phone: guest.guestPhone,
          text: l10n.claimShareMessage(name, groupName, url),
        );

    return AppSheetBody(
      title: l10n.claimSheetTitle(name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.claimSheetHelp, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.s4),
          AppCard(
            style: AppCardStyle.outlined,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: t.mono.copyWith(color: c.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                CircleIconButton(icon: AppIcons.copy, semanticLabel: l10n.claimCopySemantics, onPressed: copy),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s6),
          AppButton(
            label: l10n.claimSendWhatsApp,
            icon: AppIcons.whatsappLogo,
            block: true,
            onPressed: send,
          ),
          if (expires != null) ...[
            const SizedBox(height: AppSpace.s3),
            Text(
              l10n.claimValidUntil(
                '${AppDate.full(AppDate.jakarta(expires))} · ${AppDate.time(AppDate.jakarta(expires))}',
              ),
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
