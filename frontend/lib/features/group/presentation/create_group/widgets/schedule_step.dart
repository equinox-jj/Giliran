import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/draw_method.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/group_input.dart';
import '../controllers/create_group_controller.dart';
import 'basics_step.dart';

/// S14: start date, draw method, reminder, and the "Periksa lagi" card that
/// links back to step 1.
class const ScheduleStep({super.key, required final CreateGroupControllerProvider provider}) extends ConsumerWidget {
  static const _fieldGap = 22.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draft = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final today = AppDate.jakartaToday(ref.read(clockProvider)());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(l10n.createGroupScheduleHeadline),
        const SizedBox(height: AppSpace.s6),
        AppDateField(
          label: l10n.groupStartDateLabel,
          helper: l10n.groupStartDateHelper,
          value: draft.startDate,
          firstDate: today,
          lastDate: today.add(const Duration(days: 365)),
          errorText: fieldError(draft, 'start_date', l10n.groupStartDateError),
          onChanged: controller.setStartDate,
        ),
        const SizedBox(height: _fieldGap),
        Row(
          children: [
            Expanded(child: FieldLabel(l10n.groupDrawMethodLabel)),
            AppTextButton(
              label: l10n.profileHelpDraw,
              onPressed: () => showHelpSheet(
                context,
                title: l10n.profileHelpDraw,
                paragraphs: [l10n.profileHelpDrawBody1, l10n.profileHelpDrawBody2],
              ),
            ),
          ],
        ),
        ChoiceCardGroup<DrawMethod>(
          spacing: FieldLabel.gap,
          options: [
            ChoiceOption(
              value: DrawMethod.random,
              icon: AppIcons.shuffle,
              title: l10n.drawRandom,
              description: l10n.drawRandomDescription,
            ),
            ChoiceOption(
              value: DrawMethod.fixedOrder,
              icon: AppIcons.listNumbers,
              title: l10n.drawFixedOrder,
              description: l10n.drawFixedOrderDescription,
            ),
          ],
          value: draft.drawMethod,
          onChanged: controller.setDrawMethod,
        ),
        const SizedBox(height: _fieldGap),
        AppStepper(
          label: l10n.groupReminderLabel,
          value: draft.reminderDaysBefore,
          min: GroupRules.minReminderDays,
          max: GroupRules.maxReminderDays,
          unit: l10n.groupReminderUnit,
          helper: l10n.createGroupReminderHelper,
          onChanged: controller.setReminderDays,
        ),
        const SizedBox(height: AppSpace.s8),
        _ReviewCard(draft: draft, onEditBasics: controller.editBasics),
      ],
    );
  }
}

/// "Periksa lagi": the step-1 values, a link back to step 1, and the
/// organizer's slot note.
class const _ReviewCard({required final CreateGroupDraft draft, required final VoidCallback onEditBasics})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final unit = draft.periodType == PeriodType.weekly ? l10n.periodUnitWeekly : l10n.periodUnitMonthly;
    final slots = draft.totalSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.createGroupReview, style: t.title.copyWith(color: c.textPrimary)),
        ),
        const SizedBox(height: AppSpace.s3),
        KeyValueList(
          strongValues: true,
          items: [
            KeyValueItem(l10n.createGroupReviewName, draft.name.trim()),
            KeyValueItem(l10n.createGroupReviewDues, l10n.amountPerPeriod(Rupiah.format(draft.amount ?? 0), unit)),
            KeyValueItem(l10n.createGroupReviewSlots, l10n.createGroupReviewSlotsValue(slots, slots)),
            KeyValueItem(l10n.createGroupTotalLabel, Rupiah.format(draft.potAmount)),
          ],
          footer: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppTextButton(label: l10n.createGroupReviewEditBasics, onPressed: onEditBasics),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        Text(l10n.createGroupOrganizerSlot, style: t.caption.copyWith(color: c.textTertiary)),
      ],
    );
  }
}
