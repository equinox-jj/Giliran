import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/enums/reminder_skip_reason.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/reminder_result.dart';

/// Opens the sheet listing who the push reminder skipped.
Future<void> showSkippedRemindersSheet(
  BuildContext context, {
  required List<SkippedReminder> skipped,
  required ValueChanged<SkippedReminder> onWhatsApp,
}) => showAppSheet<void>(
  context,
  builder: (context) => SkippedRemindersSheet(skipped: skipped, onWhatsApp: onWhatsApp),
);

/// The members a push reminder skipped, grouped by reason (tamu, tidak ada
/// perangkat, notifikasi mati, baru diingatkan, sudah bayar), each with a
/// WhatsApp button when their number is known.
class const SkippedRemindersSheet({
  super.key,
  required final List<SkippedReminder> skipped,
  required final ValueChanged<SkippedReminder> onWhatsApp,
}) extends StatelessWidget {
  static String reasonLabel(AppLocalizations l10n, ReminderSkipReason? reason) => switch (reason) {
    ReminderSkipReason.guest => l10n.remindersSkipGuest,
    ReminderSkipReason.noDevice => l10n.remindersSkipNoDevice,
    ReminderSkipReason.notificationsOff => l10n.remindersSkipNotificationsOff,
    ReminderSkipReason.recentlyReminded => l10n.remindersSkipRecentlyReminded,
    ReminderSkipReason.alreadyPaid => l10n.remindersSkipAlreadyPaid,
    null => l10n.remindersSkipOther,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Known reasons in their enum order, unknown ones last.
    final reasons = <ReminderSkipReason?>[...ReminderSkipReason.values, null];
    return AppSheetBody(
      title: l10n.remindersSkippedTitle(skipped.length),
      subtitle: l10n.remindersSkippedHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final reason in reasons)
            if (skipped.where((s) => s.reason == reason).toList() case final group when group.isNotEmpty) ...[
              SectionHeader(title: reasonLabel(l10n, reason), top: AppSpace.s3),
              for (final s in group) _SkippedRow(skipped: s, onWhatsApp: () => onWhatsApp(s)),
            ],
        ],
      ),
    );
  }
}

class const _SkippedRow({required final SkippedReminder skipped, required final VoidCallback onWhatsApp})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final member = skipped.member;
    final name = member?.displayName ?? '';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.tapMin),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.body.copyWith(color: c.textPrimary)),
                Text(
                  l10n.memberSlotCaption(CodeFormatter.slotNo(member?.slotNo ?? 0)),
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (skipped.whatsappPhone != null)
            CircleIconButton(
              icon: AppIcons.whatsappLogo,
              semanticLabel: l10n.remindersWhatsAppSemantics(name),
              onPressed: onWhatsApp,
            ),
        ],
      ),
    );
  }
}
