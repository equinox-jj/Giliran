import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/draw_method.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../domain/entities/readiness.dart';
import '../controllers/start_group_controller.dart';

/// Start group: "Siap mulai arisan?", the readiness checklist with a
/// fix action per missing item, the settings summary, what happens next,
/// and "Mulai arisan" behind a confirmation sheet with a consent row. A
/// `409` from the server highlights the item it names.
class const StartGroupPage({
  super.key,
  required final String groupId,
  required final VoidCallback onInvite,
  required final VoidCallback onPaymentInfo,
  required final VoidCallback onFixedOrder,
  required final VoidCallback onStarted,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = startGroupControllerProvider(groupId);
    final group = ref.watch(provider.select((s) => s.group));
    return Scaffold(
      appBar: AppTopBar(),
      body: switch (group) {
        null => const Center(child: CircularProgressIndicator.adaptive()),
        final g when g.status != GroupStatus.draft => EmptyState(title: l10n.startNotDraft),
        final g => _StartBody(
          group: g,
          onInvite: onInvite,
          onPaymentInfo: onPaymentInfo,
          onFixedOrder: onFixedOrder,
          onStarted: onStarted,
        ),
      },
    );
  }
}

class const _StartBody({
  required final GroupDetail group,
  required final VoidCallback onInvite,
  required final VoidCallback onPaymentInfo,
  required final VoidCallback onFixedOrder,
  required final VoidCallback onStarted,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = startGroupControllerProvider(group.id ?? '');
    final items = ref.watch(provider.select((s) => s.items));
    final highlight = ref.watch(provider.select((s) => s.highlight));
    final starting = ref.watch(provider.select((s) => s.starting));
    final missing = items.where((i) => !i.done).length;
    final amount = group.amount ?? 0;
    final total = group.totalSlots ?? 0;
    final unit = group.periodType == PeriodType.weekly ? l10n.periodUnitWeekly : l10n.periodUnitMonthly;
    final start = group.startDate;

    Future<void> startGroup() async {
      final ok = await showConfirmationSheet(
        context,
        icon: AppIcons.sealCheck,
        title: l10n.startConfirmTitle(group.name ?? ''),
        confirmLabel: l10n.startButton,
        cancelLabel: l10n.commonCancel,
        consentLabel: l10n.startConsent,
      );
      if (!ok || !context.mounted) return;
      final failure = await ref.read(provider.notifier).start();
      if (!context.mounted) return;
      if (failure == null) {
        showAppToast(context, l10n.startedToast);
        onStarted();
      } else {
        showAppToast(context, failure.displayMessage(context.l10n));
      }
    }

    ReadinessRow row(ReadinessItem item) => switch (item.kind) {
      ReadinessKind.slots => ReadinessRow(
        title: l10n.readinessSlots,
        caption: l10n.readinessSlotsCaption(group.filledSlots ?? 0, total),
        done: item.done,
        highlighted: highlight == ReadinessKind.slots,
        actionLabel: l10n.membersInvite,
        onAction: onInvite,
      ),
      ReadinessKind.paymentInfo => ReadinessRow(
        title: l10n.readinessPaymentInfo,
        caption: l10n.readinessPaymentInfoCaption,
        done: item.done,
        highlighted: highlight == ReadinessKind.paymentInfo,
        actionLabel: l10n.readinessFillPaymentInfo,
        onAction: onPaymentInfo,
      ),
      ReadinessKind.fixedOrder => ReadinessRow(
        title: l10n.readinessFixedOrder,
        caption: l10n.readinessFixedOrderCaption,
        done: item.done,
        highlighted: highlight == ReadinessKind.fixedOrder,
        actionLabel: l10n.readinessSetOrder,
        onAction: onFixedOrder,
      ),
    };

    return MaxWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
        children: [
          HeadlineText(l10n.startHeadline),
          const SizedBox(height: AppSpace.s6),
          ReadinessChecklist(rows: [for (final item in items) row(item)]),
          const SizedBox(height: AppSpace.s6),
          KeyValueList(
            items: [
              KeyValueItem(l10n.startSummaryDues, l10n.amountPerPeriod(Rupiah.format(amount), unit)),
              KeyValueItem(
                l10n.startSummaryPeriod,
                group.periodType == PeriodType.weekly ? l10n.periodWeekly : l10n.periodMonthly,
              ),
              KeyValueItem(l10n.startSummaryPot, Rupiah.format(group.potAmount ?? amount * total)),
              if (start != null) KeyValueItem(l10n.startSummaryStart, AppDate.full(start)),
              KeyValueItem(
                l10n.startSummaryDraw,
                group.drawMethod == DrawMethod.fixedOrder ? l10n.drawFixedOrder : l10n.drawRandom,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.info, size: 20, color: c.textSecondary),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(l10n.startInfo, style: t.body.copyWith(color: c.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s6),
          AppButton(
            label: l10n.startButton,
            block: true,
            loading: starting,
            onPressed: missing > 0 ? null : startGroup,
          ),
          if (missing > 0) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              l10n.readinessRemaining(missing),
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
