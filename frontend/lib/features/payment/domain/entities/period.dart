import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/period_status.dart';
import '../../../member/domain/entities/member.dart';
import 'payment.dart';

part 'period.freezed.dart';

/// One round of the cycle: its dates, draw result and payment progress.
/// Feeds the Period Strip, the hero and the Pembayaran tab.
@freezed
abstract class const Period._() with _$Period {
  const factory({
    String? id,
    String? groupId,
    int? periodNo,

    /// Jakarta business dates at UTC midnight.
    DateTime? dueDate,
    DateTime? drawDate,
    PeriodStatus? status,
    String? seedHash,
    String? verificationCode,
    DateTime? drawnAt,
    MemberRef? winner,
    PaymentSummary? paymentSummary,
    bool? payoutRecorded,
    bool? payoutConfirmed,
  }) = _Period;

  bool get isUpcoming => status == PeriodStatus.upcoming;

  /// The due date is before [today] (a Jakarta business date), so unpaid
  /// rows on this period are overdue.
  bool isPastDue(DateTime today) => dueDate != null && dueDate!.isBefore(today);

  bool get isDrawn => status == PeriodStatus.drawn || status == PeriodStatus.closed;
}
