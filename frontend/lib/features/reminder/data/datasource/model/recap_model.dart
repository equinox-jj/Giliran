// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';
import '../../../../member/data/datasource/model/member_model.dart';

part 'recap_model.freezed.dart';
part 'recap_model.g.dart';

/// One unpaid member in a `Recap`; [whatsappPhone] is only filled for
/// managers.
@freezed
abstract class RecapUnpaidModel with _$RecapUnpaidModel {
  const factory({
    @JsonKey(name: 'member') MemberRefModel? member,
    @JsonKey(name: 'whatsapp_phone') String? whatsappPhone,
  }) = _RecapUnpaidModel;

  factory fromJson(Map<String, dynamic> json) => _$RecapUnpaidModelFromJson(json);
}

/// `Recap`: a period's status for the WhatsApp recap image and reminder
/// messages.
@freezed
abstract class RecapModel with _$RecapModel {
  const factory({
    @JsonKey(name: 'group_name') String? groupName,
    @JsonKey(name: 'period_no') int? periodNo,
    @JsonKey(name: 'total_periods') int? totalPeriods,
    @JsonKey(name: 'due_date') String? dueDate,
    @JsonKey(name: 'draw_date') String? drawDate,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'paid_count') int? paidCount,
    @JsonKey(name: 'total_count') int? totalCount,
    @JsonKey(name: 'collected_amount') int? collectedAmount,
    @JsonKey(name: 'expected_amount') int? expectedAmount,
    @JsonKey(name: 'unpaid') List<RecapUnpaidModel>? unpaid,
    @JsonKey(name: 'last_winner') MemberRefModel? lastWinner,
    @JsonKey(name: 'payment_info') PaymentInfoModel? paymentInfo,
  }) = _RecapModel;

  factory fromJson(Map<String, dynamic> json) => _$RecapModelFromJson(json);
}
