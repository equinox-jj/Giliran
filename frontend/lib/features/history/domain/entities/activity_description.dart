import '../../../../core/utils/enums/payment_method.dart';

/// Every activity action the API logs (DB_SCHEME §7 and the backend's
/// `model.Action`), mapped 1:1 to its API string. [unknown] covers actions
/// a newer server adds, so the row still renders.
enum ActivityKind(final String api) {
  groupCreated('group.created'),
  groupUpdated('group.updated'),
  groupPaymentInfoUpdated('group.payment_info_updated'),
  groupStarted('group.started'),
  groupClosed('group.closed'),
  groupInviteReset('group.invite_reset'),
  memberJoined('member.joined'),
  memberGuestAdded('member.guest_added'),
  memberGuestClaimed('member.guest_claimed'),
  memberGuestUpdated('member.guest_updated'),
  memberClaimLinkCreated('member.claim_link_created'),
  memberRemoved('member.removed'),
  memberLeft('member.left'),
  memberLeaveRejected('member.leave_rejected'),
  periodOpened('period.opened'),
  paymentProofUploaded('payment.proof_uploaded'),
  paymentApproved('payment.approved'),
  paymentRejected('payment.rejected'),
  paymentMarkedPaid('payment.marked_paid'),
  drawCompleted('draw.completed'),
  payoutRecorded('payout.recorded'),
  payoutConfirmed('payout.confirmed'),
  ownershipOffered('ownership.transfer_offered'),
  ownershipDeclined('ownership.transfer_declined'),
  ownershipTransferred('ownership.transferred'),
  reminderSent('reminder.sent'),
  unknown('');

  static ActivityKind fromApi(String? value) =>
      values.where((k) => k != unknown && k.api == value).firstOrNull ?? unknown;
}

/// A group setting or member detail an entry can change, for the
/// "{actor} mengubah {field}" sentence and the diff line.
enum ActivityField() {
  name,
  amount,
  periodType,
  totalSlots,
  drawMethod,
  startDate,
  reminderDaysBefore,
  fixedOrder,
  bankAccount,
  qris,
  phone,
}

/// One changed field with its old and new API values; [before] or [after]
/// is null when the field was not shown on that side.
class const ActivityDiff({required final ActivityField field, final Object? before, final Object? after});

/// What an activity row says, worked out from an entry's action, people
/// and before/after values. Presentation turns it into the localized
/// sentence and icon. Names are null when the entry has none (a system
/// actor, a member who left the account).
class const ActivityDescription({
  required final ActivityKind kind,
  final String? actorName,
  final String? subjectName,
  final int? slotNo,
  final int? periodNo,
  final String? reason,
  final PaymentMethod? method,
  final int? paidCount,
  final int? totalCount,
  final int? amount,
  final int? sentCount,
  final int? skippedCount,

  /// The payout that completed the group (`after.group_status`).
  final bool completedGroup = false,
  final List<ActivityField> changedFields = const [],

  /// Old → new values worth showing on the diff line (amount, slots, …).
  final List<ActivityDiff> diffs = const [],
}) {
  /// No account did this; the row shows the app mark.
  bool get isSystem => actorName == null;
}
