import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/next_action.dart';

/// The Home hero: the single most urgent item across my groups with
/// its group, payment ring, amount, due line and one ink button; or a calm
/// "nothing to do" panel.
class const NextActionHero({
  super.key,
  required final NextAction? action,
  required final ValueChanged<String> onOpenGroup,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = action;
    return HeroPanel(
      color: c.hero,
      decoration: const Doodle(AppDoodles.kaleng),
      child: current == null ? const _NothingToDo() : _ActionBody(action: current, onOpenGroup: onOpenGroup),
    );
  }
}

class const _NothingToDo() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.nextActionNothing,
            style: t.title.copyWith(color: c.textPrimary),
          ),
        ),
        const SizedBox(width: AppSpace.s3),
        const Doodle(AppDoodles.hands, size: 72),
      ],
    );
  }
}

class const _ActionBody({required final NextAction action, required final ValueChanged<String> onOpenGroup})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final group = action.group;
    final paid = group.paidCount ?? 0;
    final total = group.totalSlots ?? 0;
    final due = group.nextDueDate;
    final (label, button) = switch (action.kind) {
      NextActionKind.paymentRejected => (l10n.nextActionRejectedLabel, l10n.nextActionRejectedButton),
      NextActionKind.paymentDue => (l10n.nextActionDueLabel, l10n.nextActionDueButton),
      NextActionKind.reviewProofs => (l10n.nextActionReviewLabel, l10n.nextActionReviewButton(action.count ?? 0)),
      NextActionKind.drawToday => (l10n.nextActionDrawLabel, l10n.nextActionDrawButton),
      NextActionKind.confirmPayout => (l10n.nextActionPayoutLabel, l10n.nextActionPayoutButton),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.micro.copyWith(color: c.textSecondary)),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    group.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLg.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text.rich(
                    Rupiah.span(group.amount ?? 0, t.amountLg.copyWith(color: c.textPrimary)),
                  ),
                  if (due != null)
                    Text(
                      l10n.dueOn(AppDate.short(due, now: DateTime.now())),
                      style: t.body.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            GiliranRing(
              value: paid,
              total: total,
              size: GiliranRingSize.s96,
              color: c.tones[group.toneIndex % c.tones.length].accent,
              semanticsLabel: l10n.ringPaidSemantics(paid, total),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        AppButton(
          label: button,
          onPressed: () => onOpenGroup(group.id ?? ''),
        ),
      ],
    );
  }
}
