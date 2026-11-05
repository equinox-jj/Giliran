import '../../../../core/utils/enums/reminder_skip_reason.dart';
import '../../../group/data/mappers/group_mapper.dart';
import '../../../group/domain/entities/group.dart';
import '../../../member/data/mappers/member_mapper.dart';
import '../../domain/entities/recap.dart';
import '../../domain/entities/reminder_result.dart';
import '../datasource/model/recap_model.dart';
import '../datasource/model/reminder_result_model.dart';

extension RecapModelMapper on RecapModel {
  Recap toEntity() {
    final info = paymentInfo;
    return Recap(
      groupName: groupName,
      periodNo: periodNo,
      totalPeriods: totalPeriods,
      dueDate: parseBusinessDate(dueDate),
      drawDate: parseBusinessDate(drawDate),
      amount: amount,
      paidCount: paidCount,
      totalCount: totalCount,
      collectedAmount: collectedAmount,
      expectedAmount: expectedAmount,
      unpaid: [
        for (final u in unpaid ?? const <RecapUnpaidModel>[])
          RecapUnpaid(member: u.member?.toEntity(), whatsappPhone: u.whatsappPhone),
      ],
      lastWinner: lastWinner?.toEntity(),
      paymentInfo: info == null
          ? null
          : PaymentInfo(
              bankName: info.bankName,
              accountNumber: info.accountNumber,
              accountHolder: info.accountHolder,
              qrisImageUrl: info.qrisImageUrl,
              qrisMerchantName: info.qrisMerchantName,
              hasQris: info.qrisImageUrl != null,
            ),
    );
  }
}

extension ReminderResultModelMapper on ReminderResultModel {
  ReminderResult toEntity() => ReminderResult(
    sentCount: sentCount ?? 0,
    skipped: [
      for (final s in skipped ?? const <SkippedReminderModel>[])
        SkippedReminder(
          member: s.member?.toEntity(),
          reason: ReminderSkipReason.fromApi(s.reason),
          whatsappPhone: s.whatsappPhone,
        ),
    ],
  );
}
