import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/code_formatter.dart';
import '../../features/group/domain/entities/group.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_toast.dart';

/// The organizer's bank account (Tikar §8.19), so paying is copy-paste easy:
/// bank, the number grouped by 4 with "Salin" (copies digits only), and the
/// holder. Without an account it is a dashed card: "Tambahkan rekening" for
/// the organizer ([onAdd]), a note for everyone else.
class const BankAccountCard({super.key, required final PaymentInfo info, final VoidCallback? onAdd})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!info.hasBankAccount) return _MissingAccount(onAdd: onAdd);
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final digits = (info.accountNumber ?? '').replaceAll(RegExp(r'\D'), '');

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: digits));
      await HapticFeedback.lightImpact();
      if (context.mounted) showAppToast(context, l10n.accountNumberCopied);
    }

    return AppCard(
      style: AppCardStyle.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(info.bankName ?? '', style: t.title.copyWith(color: c.textPrimary)),
              ),
              AppButton.secondary(
                label: l10n.copyButton,
                icon: AppIcons.copy,
                size: AppButtonSize.xsmall,
                onPressed: copy,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            CodeFormatter.grouped(digits),
            style: t.amountLg.copyWith(color: c.textPrimary, fontFeatures: AppTextStyles.tabularFigures),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(l10n.accountHolderPrefix(info.accountHolder ?? ''), style: t.body.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class const _MissingAccount({required final VoidCallback? onAdd}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    return AppCard(
      style: AppCardStyle.dashed,
      child: Center(
        child: onAdd == null
            ? Text(
                l10n.noAccountYet,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.textSecondary),
              )
            : AppButton(label: l10n.addAccountButton, icon: AppIcons.plus, size: AppButtonSize.small, onPressed: onAdd),
      ),
    );
  }
}
