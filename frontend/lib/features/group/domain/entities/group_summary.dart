import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/member_role.dart';
import '../../../../core/utils/enums/payment_status.dart';
import '../../../../core/utils/enums/period_type.dart';

part 'group_summary.freezed.dart';

/// One group card on Home and the Groups list (API `GroupSummary`).
@freezed
abstract class const GroupSummary._() with _$GroupSummary {
  const factory({
    String? id,
    String? name,
    int? amount,
    PeriodType? periodType,
    GroupStatus? status,
    MemberRole? myRole,
    int? totalSlots,
    int? filledSlots,
    int? currentPeriodNo,

    /// Jakarta business dates at UTC midnight.
    DateTime? nextDueDate,
    DateTime? nextDrawDate,

    /// Null when no period is open.
    PaymentStatus? myPaymentStatus,
    int? paidCount,

    /// Organizers only: proofs waiting for review.
    int? pendingReviewCount,
    bool? iHaveWon,
  }) = _GroupSummary;

  /// Index into `GiliranColors.tones`, stable per group.
  int get toneIndex => GiliranColors.toneIndexFor(id ?? '');

  bool get isManager => myRole == MemberRole.organizer || myRole == MemberRole.coOrganizer;
}
