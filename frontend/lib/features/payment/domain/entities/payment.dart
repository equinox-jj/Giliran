import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/payment_method.dart';
import '../../../../core/utils/enums/payment_status.dart';
import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';

part 'payment.freezed.dart';

/// One slot's dues for one period: a row on the payment board (S20), and
/// with [proofs] the detail Proof review (S35) reads.
@freezed
abstract class const Payment._() with _$Payment {
  const factory({
    String? id,
    String? groupId,
    String? periodId,
    MemberRef? member,
    int? amount,
    PaymentStatus? status,
    PaymentMethod? method,

    /// The proof under review. Cached rows know only its id; the signed
    /// URL comes with a fresh server response.
    PaymentProof? currentProof,
    String? note,
    String? rejectReason,
    DateTime? paidAt,
    UserSummary? reviewedBy,
    DateTime? reviewedAt,
    bool? isMine,
    DateTime? updatedAt,

    /// Every uploaded proof, newest first; only on `GET /payments/{id}`.
    List<PaymentProof>? proofs,

    /// An organizer's offline cash mark not yet sent to the server.
    bool? pendingSync,
  }) = _Payment;

  bool get mine => isMine ?? false;

  bool get isPendingSync => pendingSync ?? false;

  /// Still owed: unpaid, or a rejected proof that needs a new upload.
  bool get isOutstanding => status == PaymentStatus.unpaid || status == PaymentStatus.rejected;

  /// When the current proof was uploaded. A cached row has no proof
  /// timestamp, and uploading a proof is what last changed a pending
  /// payment, so [updatedAt] stands in for it.
  DateTime? get uploadedAt => currentProof?.uploadedAt ?? updatedAt;
}

/// An uploaded transfer screenshot.
@freezed
abstract class PaymentProof with _$PaymentProof {
  const factory({
    String? id,

    /// Signed URL valid for 10 minutes.
    String? url,
    String? contentType,
    DateTime? uploadedAt,
  }) = _PaymentProof;
}

/// A period's payment counts and amounts, for the summary line, the hero
/// ring and the Period Strip.
@freezed
abstract class const PaymentSummary._() with _$PaymentSummary {
  const factory({
    int? totalCount,
    int? paidCount,
    int? pendingReviewCount,
    int? unpaidCount,
    int? rejectedCount,
    int? collectedAmount,
    int? expectedAmount,
  }) = _PaymentSummary;

  /// Counts a board's rows, including offline marks the server hasn't seen.
  factory fromPayments(List<Payment> payments) {
    int count(PaymentStatus s) => payments.where((p) => p.status == s).length;
    return PaymentSummary(
      totalCount: payments.length,
      paidCount: count(PaymentStatus.paid),
      pendingReviewCount: count(PaymentStatus.pendingReview),
      unpaidCount: count(PaymentStatus.unpaid),
      rejectedCount: count(PaymentStatus.rejected),
      collectedAmount: payments
          .where((p) => p.status == PaymentStatus.paid)
          .fold<int>(0, (sum, p) => sum + (p.amount ?? 0)),
      expectedAmount: payments.fold<int>(0, (sum, p) => sum + (p.amount ?? 0)),
    );
  }

  /// Unpaid plus rejected: still owed this period.
  int get outstandingCount => (unpaidCount ?? 0) + (rejectedCount ?? 0);

  bool get allPaid => (totalCount ?? 0) > 0 && paidCount == totalCount;
}

/// What a sync of offline cash marks did: how many the server accepted,
/// and the payments it refused (now back to server state).
@freezed
abstract class SyncReport with _$SyncReport {
  const factory({
    @Default(0) int synced,
    @Default(<Payment>[]) List<Payment> rejected,
  }) = _SyncReport;
}
