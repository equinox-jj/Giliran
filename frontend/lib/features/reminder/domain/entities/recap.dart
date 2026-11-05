import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';

part 'recap.freezed.dart';

/// An unpaid member on the recap. [whatsappPhone] (`+62…`) is only known to
/// managers, for one-tap WhatsApp reminders; it never goes on the image.
@freezed
abstract class RecapUnpaid with _$RecapUnpaid {
  const factory({MemberRef? member, String? whatsappPhone}) = _RecapUnpaid;
}

/// A period's status for Reminders and recap (S41): what the WhatsApp recap
/// image shows and what the reminder messages quote.
@freezed
abstract class const Recap._() with _$Recap {
  const factory({
    String? groupName,
    int? periodNo,
    int? totalPeriods,

    /// Jakarta business dates at UTC midnight.
    DateTime? dueDate,
    DateTime? drawDate,
    int? amount,
    int? paidCount,
    int? totalCount,
    int? collectedAmount,
    int? expectedAmount,

    /// Unpaid or rejected payments, by slot number.
    @Default(<RecapUnpaid>[]) List<RecapUnpaid> unpaid,
    MemberRef? lastWinner,
    PaymentInfo? paymentInfo,
  }) = _Recap;

  bool get allPaid => unpaid.isEmpty;
}
