import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/group_input.dart';
import '../../../domain/usecases/due_date_usecase.dart';
import '../controllers/create_group_controller.dart';

/// Step 1: name, dues, period and slots. The pot summary is pinned under the
/// form by the page.
class const BasicsStep({
  super.key,
  required final CreateGroupPrefill prefill,
  required final TextEditingController nameController,
  required final TextEditingController amountController,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = createGroupControllerProvider(
      prefillAmount: prefill.amount,
      prefillPeriodType: prefill.periodType,
      prefillTotalSlots: prefill.totalSlots,
    );
    final draft = ref.watch(provider);
    final controller = ref.watch(provider.notifier);
    final amount = draft.amount;
    final start = draft.startDate;
    final end = start == null
        ? null
        : ref.read(dueDateUseCaseProvider)(start: start, periodType: draft.periodType, periodNo: draft.totalSlots);
    final slots = draft.totalSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(l10n.createGroupBasicsHeadline),
        const SizedBox(height: AppSpace.s6),
        AppTextField(
          controller: nameController,
          label: l10n.groupNameLabel,
          hint: l10n.groupNameHint,
          helper: l10n.groupNameHelper,
          errorText:
              fieldError(draft, 'name', l10n.groupNameError) ??
              (draft.name.trim().length > GroupRules.maxNameLength ? l10n.groupNameError : null),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: controller.setName,
        ),
        const SizedBox(height: AppSpace.s5),
        AmountField(
          controller: amountController,
          label: l10n.groupAmountLabel,
          helper: l10n.groupAmountHelper,
          errorText:
              fieldError(draft, 'amount', l10n.groupAmountError) ??
              (amount != null && (amount < GroupRules.minAmount || amount > GroupRules.maxAmount)
                  ? l10n.groupAmountError
                  : null),
          onChanged: controller.setAmount,
        ),
        const SizedBox(height: AppSpace.s5),
        FieldLabel(l10n.groupPeriodLabel),
        const SizedBox(height: FieldLabel.gap),
        ChoiceCardGroup<PeriodType>(
          spacing: FieldLabel.gap,
          options: [
            ChoiceOption(
              value: PeriodType.monthly,
              icon: AppIcons.calendarBlank,
              title: l10n.periodMonthly,
              description: l10n.periodMonthlyDescription,
            ),
            ChoiceOption(
              value: PeriodType.weekly,
              icon: AppIcons.calendarDots,
              title: l10n.periodWeekly,
              description: l10n.periodWeeklyDescription,
            ),
          ],
          value: draft.periodType,
          onChanged: controller.setPeriodType,
        ),
        const SizedBox(height: AppSpace.s5),
        AppStepper(
          label: l10n.groupSlotsLabel,
          value: slots,
          min: GroupRules.minSlots,
          max: GroupRules.maxSlots,
          unit: l10n.groupSlotsUnit,
          helper:
              fieldError(draft, 'total_slots', l10n.groupSlotsError) ??
              (end == null
                  ? l10n.createGroupSlotsPeriods(slots)
                  : l10n.createGroupSlotsPeriodsEnd(slots, AppDate.full(end))),
          onChanged: controller.setTotalSlots,
        ),
      ],
    );
  }
}

/// A form label that isn't attached to a text field ("Periode", "Cara
/// menentukan giliran"), styled like [AppTextField]'s label.
class const FieldLabel(final String text, {super.key}) extends StatelessWidget {
  /// Space between the label and what it labels, and between choice cards.
  static const gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: t.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The error to show under [field]: the server's message, or [fallback] for
/// a device-side check (which carries no message). Null when the field is
/// fine.
String? fieldError(CreateGroupDraft draft, String field, String fallback) {
  final message = draft.failure?.fieldMessage(field);
  if (message == null) return null;
  return message.isEmpty ? fallback : message;
}
