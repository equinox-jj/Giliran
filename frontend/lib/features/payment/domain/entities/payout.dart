import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';

part 'payout.freezed.dart';

/// The record that a period's pot was handed to its winner.
@freezed
abstract class Payout with _$Payout {
  const factory({
    String? id,
    String? periodId,
    MemberRef? winner,
    int? amount,

    /// Signed and short-lived; cached payouts know only [hasProof].
    String? proofUrl,
    bool? hasProof,
    String? note,
    UserSummary? recordedBy,
    DateTime? recordedAt,
    DateTime? confirmedAt,
  }) = _Payout;
}
