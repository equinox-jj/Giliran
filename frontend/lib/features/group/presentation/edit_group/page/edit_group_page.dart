import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/draw_method.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../core/utils/enums/member_role.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/entities/group_input.dart';
import '../../group_detail/controllers/group_detail_controller.dart';
import '../controllers/edit_group_controller.dart';
import '../widgets/edit_sheets.dart';

/// Edit group (S19): settings rows that each save on their own. The group
/// rules lock once the group has started; the organizer can close the group
/// from the danger zone.
class const EditGroupPage({
  super.key,
  required final String groupId,
  required final VoidCallback onPaymentInfo,
  required final VoidCallback onFixedOrder,
  required final VoidCallback onLeaveRequests,
  required final VoidCallback onTransfer,

  /// Opens Reminders and recap (S41).
  required final VoidCallback onReminders,

  /// Called after the group was closed.
  required final VoidCallback onClosed,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group));
    return Scaffold(
      appBar: AppTopBar(title: context.l10n.editGroupTitle),
      body: group == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _EditGroupBody(
              group: group,
              onPaymentInfo: onPaymentInfo,
              onFixedOrder: onFixedOrder,
              onLeaveRequests: onLeaveRequests,
              onTransfer: onTransfer,
              onReminders: onReminders,
              onClosed: onClosed,
            ),
    );
  }
}

class const _EditGroupBody({
  required final GroupDetail group,
  required final VoidCallback onPaymentInfo,
  required final VoidCallback onFixedOrder,
  required final VoidCallback onLeaveRequests,
  required final VoidCallback onTransfer,
  required final VoidCallback onReminders,
  required final VoidCallback onClosed,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = editGroupControllerProvider(group.id ?? '');
    // Watched so the controller stays alive while a save is in flight.
    ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final draft = group.status == GroupStatus.draft;
    final organizer = group.myRole == MemberRole.organizer;
    final reminder = group.reminderDaysBefore ?? GroupRules.defaultReminderDays;
    final periodLabel = group.periodType == PeriodType.weekly ? l10n.periodWeekly : l10n.periodMonthly;
    final drawLabel = group.drawMethod == DrawMethod.fixedOrder ? l10n.drawFixedOrder : l10n.drawRandom;
    final start = group.startDate;
    final startLabel = start == null ? '' : AppDate.full(start);
    final account = group.paymentInfo;
    final digits = (account?.accountNumber ?? '').replaceAll(RegExp(r'\D'), '');
    final accountLabel = account != null && account.hasBankAccount
        ? '${account.bankName} · ${digits.length > 4 ? digits.substring(digits.length - 4) : digits}'
        : null;

    Future<void> save(UpdateGroupInput input) async {
      final failure = await controller.save(input);
      if (!context.mounted) return;
      showAppToast(context, failure == null ? l10n.editGroupSaved : _message(context, failure));
    }

    Future<void> edit<T>(Widget sheet, UpdateGroupInput Function(T value) toInput) async {
      final value = await showAppSheet<T>(context, builder: (_) => sheet);
      if (value != null) await save(toInput(value));
    }

    Future<void> close() async {
      final confirmed = await showAppDialog(
        context,
        title: l10n.closeGroupTitle(group.name ?? ''),
        message: l10n.closeGroupMessage,
        confirmLabel: l10n.menuClose,
      );
      if (!confirmed || !context.mounted) return;
      final failure = await controller.close();
      if (!context.mounted) return;
      showAppToast(context, failure?.displayMessage(context.l10n) ?? l10n.groupClosedToast);
      if (failure == null) onClosed();
    }

    Future<void> pickStart() async {
      final today = AppDate.jakartaToday(ref.read(clockProvider)());
      final picked = await AppDatePicker.show(
        context,
        initialDate: start != null && !start.isBefore(today) ? start : today,
        firstDate: today,
        lastDate: today.add(const Duration(days: 365)),
      );
      if (picked != null) {
        await save(UpdateGroupInput(startDate: DateTime.utc(picked.year, picked.month, picked.day)));
      }
    }

    final rules = <(String, String, String, VoidCallback)>[
      (
        AppIcons.money,
        l10n.editGroupDues,
        Rupiah.format(group.amount ?? 0),
        () => edit<int>(
          AmountValueSheet(title: l10n.groupAmountLabel, label: l10n.groupAmountLabel, initial: group.amount ?? 0),
          (v) => UpdateGroupInput(amount: v),
        ),
      ),
      (
        AppIcons.calendarBlank,
        l10n.groupPeriodLabel,
        periodLabel,
        () => edit<PeriodType>(
          ChoiceValueSheet<PeriodType>(
            title: l10n.groupPeriodLabel,
            initial: group.periodType ?? PeriodType.monthly,
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
          ),
          (v) => UpdateGroupInput(periodType: v),
        ),
      ),
      (
        AppIcons.user,
        l10n.groupSlotsLabel,
        '${group.totalSlots ?? 0}',
        () => edit<int>(
          StepperValueSheet(
            title: l10n.groupSlotsLabel,
            label: l10n.groupSlotsLabel,
            initial: group.totalSlots ?? GroupRules.minSlots,
            min: GroupRules.minSlots,
            max: GroupRules.maxSlots,
            unit: l10n.groupSlotsUnit,
          ),
          (v) => UpdateGroupInput(totalSlots: v),
        ),
      ),
      (AppIcons.flag, l10n.groupStartDateLabel, startLabel, pickStart),
      (
        AppIcons.shuffle,
        l10n.editGroupDrawMethod,
        drawLabel,
        () => edit<DrawMethod>(
          ChoiceValueSheet<DrawMethod>(
            title: l10n.groupDrawMethodLabel,
            initial: group.drawMethod ?? DrawMethod.random,
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
          ),
          (v) => UpdateGroupInput(drawMethod: v),
        ),
      ),
    ];

    return MaxWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
        children: [
          SettingsGroup(
            header: l10n.editGroupGeneral,
            children: [
              SettingsRow.navigation(
                icon: AppIcons.pencilSimple,
                label: l10n.groupNameLabel,
                value: group.name,
                onTap: () => edit<String>(
                  TextValueSheet(title: l10n.groupNameLabel, label: l10n.groupNameLabel, initial: group.name ?? ''),
                  (v) => UpdateGroupInput(name: v),
                ),
              ),
              SettingsRow.navigation(
                icon: AppIcons.bellSimple,
                label: l10n.groupReminderLabel,
                value: reminder == 0 ? l10n.groupReminderSameDay : l10n.editGroupReminderValue(reminder),
                onTap: () => edit<int>(
                  StepperValueSheet(
                    title: l10n.groupReminderLabel,
                    label: l10n.groupReminderLabel,
                    initial: reminder,
                    min: GroupRules.minReminderDays,
                    max: GroupRules.maxReminderDays,
                    unit: l10n.groupReminderUnit,
                  ),
                  (v) => UpdateGroupInput(reminderDaysBefore: v),
                ),
              ),
            ],
          ),
          SettingsGroup(
            header: l10n.editGroupRules,
            footer: draft ? null : l10n.editGroupLocked,
            children: [
              for (final (icon, label, value, onTap) in rules)
                draft
                    ? SettingsRow.navigation(icon: icon, label: label, value: value, onTap: onTap)
                    : SettingsRow.locked(icon: icon, label: label, value: value),
            ],
          ),
          SettingsGroup(
            header: l10n.editGroupManagers,
            children: [
              SettingsRow.navigation(
                icon: AppIcons.bank,
                label: l10n.menuPaymentInfo,
                value: accountLabel,
                onTap: onPaymentInfo,
              ),
              if (draft && group.drawMethod == DrawMethod.fixedOrder)
                SettingsRow.navigation(
                  icon: AppIcons.listNumbers,
                  label: l10n.editGroupFixedOrder,
                  onTap: onFixedOrder,
                ),
              SettingsRow.navigation(
                icon: AppIcons.chatCircle,
                label: l10n.editGroupRemindersRecap,
                onTap: onReminders,
              ),
              SettingsRow.navigation(
                icon: AppIcons.signOut,
                label: l10n.editGroupLeaveRequests,
                onTap: onLeaveRequests,
              ),
              if (organizer)
                SettingsRow.navigation(
                  icon: AppIcons.crown,
                  label: l10n.editGroupTransfer,
                  onTap: onTransfer,
                ),
            ],
          ),
          if (organizer && group.status != GroupStatus.closed)
            SettingsGroup(
              header: l10n.editGroupDanger,
              children: [
                SettingsRow.destructive(
                  icon: AppIcons.archive,
                  label: l10n.menuClose,
                  subtitle: l10n.closeGroupSubtitle,
                  onTap: close,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// The toast for a failed save: the lock caption for `group_not_draft`,
  /// the server's field message for a 422, else the default message.
  static String _message(BuildContext context, Failure failure) {
    if (failure.apiCode == ApiErrorCode.groupNotDraft) return context.l10n.editGroupLocked;
    if (failure case ValidationFailure(:final fieldErrors) when fieldErrors.isNotEmpty) {
      final message = fieldErrors.first.message;
      if (message.isNotEmpty) return message;
      return switch (fieldErrors.first.field) {
        'name' => context.l10n.groupNameError,
        'amount' => context.l10n.groupAmountError,
        'total_slots' => context.l10n.groupSlotsError,
        _ => failure.displayMessage(context.l10n),
      };
    }
    return failure.displayMessage(context.l10n);
  }
}
