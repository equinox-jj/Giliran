import 'package:freezed_annotation/freezed_annotation.dart';

import 'member.dart';

part 'obligation.freezed.dart';

/// What a past winner still owes after their period (Obligation Meter,
/// §9.6).
@freezed
abstract class const Obligation._() with _$Obligation {
  const factory({
    MemberRef? member,
    int? wonPeriodNo,
    int? remainingCount,
    int? remainingAmount,
    int? overdueCount,
    int? overdueAmount,
  }) = _Obligation;

  String? get memberId => member?.id;

  bool get isOverdue => (overdueCount ?? 0) > 0;
}
