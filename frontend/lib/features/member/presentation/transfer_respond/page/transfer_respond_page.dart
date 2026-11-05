import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../controllers/transfer_respond_controller.dart';

/// Transfer ownership respond (S33): "{from} ingin kamu jadi pengurus
/// {group}", the three responsibilities, the payment info reminder, and
/// "Terima" / "Tolak". The API can't read one transfer back, so the names
/// come from the cached group (its current organizer). After accepting,
/// [onAccepted] opens Payment info (S15).
class const TransferRespondPage({
  super.key,
  required final String groupId,
  required final String transferId,
  required final VoidCallback onAccepted,
  required final VoidCallback onDone,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final group = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group));
    final provider = transferRespondControllerProvider(groupId, transferId);
    final busy = ref.watch(provider);

    Future<void> answer({required bool accept}) async {
      final notifier = ref.read(provider.notifier);
      final failure = accept ? await notifier.accept() : await notifier.decline();
      if (!context.mounted) return;
      if (failure == null) {
        showAppToast(context, accept ? l10n.transferAccepted : l10n.transferDeclined);
        accept ? onAccepted() : onDone();
      } else {
        final gone = failure is NotFoundFailure || failure is ConflictFailure || failure is ForbiddenFailure;
        showAppToast(context, gone ? l10n.transferExpired : failure.displayMessage(context.l10n));
      }
    }

    return Scaffold(
      appBar: AppTopBar(onBack: onDone),
      body: group == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : MaxWidth(
              child: ListView(
                padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
                children: [
                  const Center(child: Doodle(AppDoodles.crown, size: 120)),
                  const SizedBox(height: AppSpace.s4),
                  HeadlineText(l10n.transferRespondHeadline(group.organizer?.name ?? '', group.name ?? '')),
                  const SizedBox(height: AppSpace.s6),
                  // Three fixed bullets.
                  for (final duty in [l10n.transferDutyPayments, l10n.transferDutyDraws, l10n.transferDutyMembers])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppIcon(AppIcons.checkCircle, size: 20, color: c.paid.fg),
                          const SizedBox(width: AppSpace.s2),
                          Expanded(
                            child: Text(duty, style: t.body.copyWith(color: c.textPrimary)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpace.s3),
                  AppBanner(message: l10n.transferReminder, icon: AppIcons.bank),
                  const SizedBox(height: AppSpace.s8),
                  AppButton(
                    label: l10n.transferAccept,
                    block: true,
                    loading: busy,
                    onPressed: () => answer(accept: true),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  AppButton.secondary(
                    label: l10n.transferDecline,
                    block: true,
                    onPressed: busy ? null : () => answer(accept: false),
                  ),
                ],
              ),
            ),
    );
  }
}
