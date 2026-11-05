import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../group/domain/entities/group_summary.dart';

part 'next_action.freezed.dart';

/// What the Home hero asks for, most urgent first.
enum NextActionKind() {
  /// My proof was rejected; upload a new one.
  paymentRejected,

  /// My payment is due within 3 days (or overdue).
  paymentDue,

  /// I manage the group and proofs wait for review.
  reviewProofs,

  /// I manage the group and today is the draw date.
  drawToday,

  /// I won and the payout waits for my confirmation.
  confirmPayout,
}

/// The single most urgent item across my groups, shown in the Home hero.
@freezed
abstract class NextAction with _$NextAction {
  const factory({
    required NextActionKind kind,
    required GroupSummary group,

    /// Proofs to review for [NextActionKind.reviewProofs].
    int? count,
  }) = _NextAction;
}
