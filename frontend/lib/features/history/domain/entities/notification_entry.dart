/// The push kinds the worker sends (`data.type`, backend `notify.Kind`).
enum PushKind(final String api) {
  paymentReminder('payment.reminder'),
  proofUploaded('payment.proof_uploaded'),
  paymentApproved('payment.approved'),
  paymentRejected('payment.rejected'),
  paymentMarkedPaid('payment.marked_paid'),
  drawCompleted('draw.completed'),
  payoutRecorded('payout.recorded'),
  obligationsMissed('obligations.missed'),
  unknown('');

  static PushKind fromApi(String? value) => values.where((k) => k != unknown && k.api == value).firstOrNull ?? unknown;

  /// Kinds that ask the reader to do something (pay, review, confirm,
  /// follow up), for the "Perlu tindakan" chip.
  bool get needsAction => switch (this) {
    paymentReminder || proofUploaded || paymentRejected || payoutRecorded || obligationsMissed => true,
    _ => false,
  };
}

/// A push stored on this device for the Aktivitas tab (S12). The read flag
/// is local only.
class const NotificationEntry({
  required final String id,
  required final PushKind kind,
  final String? groupId,

  /// From the group cache; null when the group isn't cached.
  final String? groupName,
  final String? periodId,
  final String? paymentId,
  final String? payoutId,
  final String? title,
  final String? body,
  required final DateTime createdAt,
  final bool read = false,
}) {
  /// Unread and asking for an action ("Perlu tindakan").
  bool get pendingAction => !read && kind.needsAction;
}

/// The S12 filter chips: Semua · Belum dibaca · Perlu tindakan.
enum NotificationFilter() {
  all,
  unread,
  needsAction,
}

/// Where tapping a notification goes (Tikar 8.24, route map §10.2).
sealed class const NotificationTarget();

/// The Aktivitas tab itself, when the push names no group.
final class const InboxTarget() extends NotificationTarget;

/// The group detail tab a notification opens.
enum GroupTargetTab() {
  payments,
  members,
}

/// A group's detail on [tab], or its default tab.
final class const GroupTarget(final String groupId, {final GroupTargetTab? tab}) extends NotificationTarget;

/// Proof review (S35).
final class const ProofReviewTarget(final String groupId, final String paymentId) extends NotificationTarget;

/// Bukti Kocok (S38).
final class const DrawResultTarget(final String groupId, final String periodId) extends NotificationTarget;

/// Payout (S40), where the winner confirms.
final class const PayoutTarget(final String groupId, final String periodId) extends NotificationTarget;
