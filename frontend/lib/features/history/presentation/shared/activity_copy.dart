import '../../../../core/constants/app_icons.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/themes/themes.dart';
import '../../../../core/utils/code_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/payment_method.dart';
import '../../../../core/utils/enums/period_type.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/activity_description.dart';

/// The localized sentence, icon and diff lines of an activity row
/// (Tikar 8.23) for a described entry.
extension ActivityDescriptionCopy on ActivityDescription {
  String sentence(AppLocalizations l10n) {
    final actor = actorName ?? l10n.activitySystemName;
    final subject = subjectName ?? l10n.activityFormerMember;
    final slot = slotNo == null ? null : CodeFormatter.slotNo(slotNo!);
    return switch (kind) {
      ActivityKind.groupCreated => l10n.activityGroupCreated(actor),
      ActivityKind.groupUpdated => l10n.activityGroupUpdated(actor, _fields(l10n)),
      ActivityKind.groupPaymentInfoUpdated => l10n.activityGroupPaymentInfo(actor),
      ActivityKind.groupStarted => l10n.activityGroupStarted,
      ActivityKind.groupClosed => l10n.activityGroupClosed(actor),
      ActivityKind.groupInviteReset => l10n.activityInviteReset(actor),
      ActivityKind.memberJoined =>
        slot == null ? l10n.activityMemberJoinedNoSlot(subject) : l10n.activityMemberJoined(subject, slot),
      ActivityKind.memberGuestAdded => l10n.activityGuestAdded(actor, subject),
      ActivityKind.memberGuestClaimed => l10n.activityGuestClaimed(subject),
      ActivityKind.memberGuestUpdated => l10n.activityGuestUpdated(actor, subject),
      ActivityKind.memberClaimLinkCreated => l10n.activityClaimLink(actor, subject),
      ActivityKind.memberRemoved => l10n.activityMemberRemoved(actor, subject),
      ActivityKind.memberLeft => l10n.activityMemberLeft(subject),
      ActivityKind.memberLeaveRejected => l10n.activityLeaveRejected(actor, subject),
      ActivityKind.periodOpened =>
        periodNo == null ? l10n.activityPeriodOpenedNoNumber : l10n.activityPeriodOpened('$periodNo'),
      ActivityKind.paymentProofUploaded => l10n.activityProofUploaded(subject),
      ActivityKind.paymentApproved => l10n.activityPaymentApproved(actor, subject),
      ActivityKind.paymentRejected =>
        reason == null
            ? l10n.activityPaymentRejectedNoReason(actor, subject)
            : l10n.activityPaymentRejected(actor, subject, reason!),
      ActivityKind.paymentMarkedPaid =>
        method == null
            ? l10n.activityMarkedPaidNoMethod(actor, subject)
            : l10n.activityMarkedPaid(actor, subject, switch (method!) {
                PaymentMethod.cash => l10n.activityMethodCash,
                PaymentMethod.transfer => l10n.activityMethodTransfer,
                PaymentMethod.other => l10n.activityMethodOther,
              }),
      ActivityKind.drawCompleted => _draw(l10n, slot),
      ActivityKind.payoutRecorded => _payout(l10n, actor, subject),
      ActivityKind.payoutConfirmed => l10n.activityPayoutConfirmed(subject),
      ActivityKind.ownershipOffered => l10n.activityOwnershipOffered(actor, subject),
      ActivityKind.ownershipDeclined => l10n.activityOwnershipDeclined(subject),
      // The accepting member is the actor; group entries have no subject.
      ActivityKind.ownershipTransferred => l10n.activityOwnershipTransferred(actorName ?? subject),
      ActivityKind.reminderSent => l10n.activityReminderSent(actor, sentCount ?? 0),
      ActivityKind.unknown => l10n.activityUnknown(actor),
    };
  }

  /// The row's icon (Phosphor via [AppIcons]).
  String get icon => switch (kind) {
    ActivityKind.groupCreated => AppIcons.plus,
    ActivityKind.groupUpdated => AppIcons.pencilSimple,
    ActivityKind.groupPaymentInfoUpdated => AppIcons.bank,
    ActivityKind.groupStarted => AppIcons.flag,
    ActivityKind.groupClosed => AppIcons.archive,
    ActivityKind.groupInviteReset => AppIcons.linkSimple,
    ActivityKind.memberJoined => AppIcons.userPlus,
    ActivityKind.memberGuestAdded => AppIcons.userCircleDashed,
    ActivityKind.memberGuestClaimed => AppIcons.userCircle,
    ActivityKind.memberGuestUpdated => AppIcons.pencilSimple,
    ActivityKind.memberClaimLinkCreated => AppIcons.linkSimple,
    ActivityKind.memberRemoved => AppIcons.minus,
    ActivityKind.memberLeft || ActivityKind.memberLeaveRejected => AppIcons.signOut,
    ActivityKind.periodOpened => AppIcons.calendarDots,
    ActivityKind.paymentProofUploaded => AppIcons.receipt,
    ActivityKind.paymentApproved => AppIcons.checkCircle,
    ActivityKind.paymentRejected => AppIcons.xCircle,
    ActivityKind.paymentMarkedPaid => AppIcons.money,
    ActivityKind.drawCompleted => AppIcons.shuffle,
    ActivityKind.payoutRecorded => AppIcons.handCoins,
    ActivityKind.payoutConfirmed => AppIcons.sealCheck,
    ActivityKind.ownershipOffered ||
    ActivityKind.ownershipDeclined ||
    ActivityKind.ownershipTransferred => AppIcons.crown,
    ActivityKind.reminderSent => AppIcons.bellRinging,
    ActivityKind.unknown => AppIcons.info,
  };

  /// One "label ~~old~~ → new" line per diff with both values known.
  List<ActivityRowDiff> diffLines(AppLocalizations l10n, {DateTime? now}) => [
    for (final d in diffs)
      if (d.before != null && d.after != null)
        ActivityRowDiff(
          label: _fieldLabel(l10n, d.field, guest: kind == ActivityKind.memberGuestUpdated),
          before: _value(l10n, d.field, d.before, now),
          after: _value(l10n, d.field, d.after, now),
        ),
  ];

  String _fields(AppLocalizations l10n) => changedFields.isEmpty
      ? l10n.activityFieldsFallback
      : [for (final f in changedFields) _fieldLabel(l10n, f)].join(', ');

  String _draw(AppLocalizations l10n, String? slot) {
    final head = slot == null ? l10n.activityDrawCompletedNoSlot : l10n.activityDrawCompleted(slot);
    if (paidCount == null || totalCount == null) return head;
    return '$head (${l10n.activityDrawPaidCount(paidCount!, totalCount!)})';
  }

  String _payout(AppLocalizations l10n, String actor, String subject) {
    final head = amount == null
        ? l10n.activityPayoutRecordedNoAmount(actor, subject)
        : l10n.activityPayoutRecorded(actor, Rupiah.format(amount!), subject);
    return completedGroup ? '$head · ${l10n.activityGroupCompletedSuffix}' : head;
  }

  static String _fieldLabel(AppLocalizations l10n, ActivityField field, {bool guest = false}) => switch (field) {
    ActivityField.name => guest ? l10n.activityFieldGuestName : l10n.activityFieldName,
    ActivityField.amount => l10n.activityFieldAmount,
    ActivityField.periodType => l10n.activityFieldPeriodType,
    ActivityField.totalSlots => l10n.activityFieldTotalSlots,
    ActivityField.drawMethod => l10n.activityFieldDrawMethod,
    ActivityField.startDate => l10n.activityFieldStartDate,
    ActivityField.reminderDaysBefore => l10n.activityFieldReminder,
    ActivityField.fixedOrder => l10n.activityFieldFixedOrder,
    ActivityField.bankAccount => l10n.activityFieldBankAccount,
    ActivityField.qris => l10n.activityFieldQris,
    ActivityField.phone => l10n.activityFieldPhone,
  };

  static String _value(AppLocalizations l10n, ActivityField field, Object? value, DateTime? now) {
    switch (field) {
      case ActivityField.amount when value is num:
        return Rupiah.format(value.toInt());
      case ActivityField.periodType:
        return switch (PeriodType.fromApi(value?.toString())) {
          PeriodType.weekly => l10n.periodWeekly,
          PeriodType.monthly => l10n.periodMonthly,
          null => '$value',
        };
      case ActivityField.drawMethod:
        return switch (DrawMethod.fromApi(value?.toString())) {
          DrawMethod.random => l10n.drawRandom,
          DrawMethod.fixedOrder => l10n.drawFixedOrder,
          null => '$value',
        };
      case ActivityField.startDate:
        final date = DateTime.tryParse('$value');
        return date == null ? '$value' : AppDate.short(DateTime.utc(date.year, date.month, date.day), now: now);
      case ActivityField.reminderDaysBefore when value is num:
        return l10n.activityReminderDays(value.toInt());
      default:
        return '$value';
    }
  }
}
