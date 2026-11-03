import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/member_role.dart';
import '../../../../core/utils/enums/payment_status.dart';
import '../../../../core/utils/enums/period_type.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_input.dart';
import '../../domain/entities/group_summary.dart';
import '../datasource/model/group_model.dart';
import '../datasource/model/group_request_model.dart';
import '../datasource/model/group_summary_model.dart';

/// Parses an API business date (`yyyy-MM-dd`) to UTC midnight.
DateTime? parseBusinessDate(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final [y, m, d] = parts.map(int.tryParse).toList();
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

/// Formats a business date as the API's `yyyy-MM-dd`.
String formatBusinessDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

PaymentStatus? _paymentStatus(String? value) => value == null ? null : PaymentStatus.fromApi(value);

extension GroupModelMapper on GroupModel {
  GroupDetail toEntity() => GroupDetail(
    id: id,
    name: name,
    amount: amount,
    potAmount: potAmount,
    periodType: PeriodType.fromApi(periodType),
    totalSlots: totalSlots,
    filledSlots: filledSlots,
    drawMethod: DrawMethod.fromApi(drawMethod),
    startDate: parseBusinessDate(startDate),
    reminderDaysBefore: reminderDaysBefore,
    status: GroupStatus.fromApi(status),
    organizer: organizer == null
        ? null
        : UserSummary(
            id: organizer?.id,
            name: organizer?.name,
            avatarUrl: organizer?.avatarUrl,
          ),
    myRole: MemberRole.fromApi(myRole),
    myMemberId: myMemberId,
    invite: invite == null ? null : Invite(code: invite?.inviteCode, url: invite?.inviteUrl),
    paymentInfo: PaymentInfo(
      bankName: paymentInfo?.bankName,
      accountNumber: paymentInfo?.accountNumber,
      accountHolder: paymentInfo?.accountHolder,
      qrisImageUrl: paymentInfo?.qrisImageUrl,
      qrisMerchantName: paymentInfo?.qrisMerchantName,
      hasQris: paymentInfo?.qrisImageUrl != null,
    ),
    currentPeriodId: currentPeriodId,
    startedAt: startedAt,
    completedAt: completedAt,
    closedAt: closedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// The detail columns only; the summary-only columns stay absent so the
  /// card numbers from the last list fetch survive.
  GroupsCompanion toCompanion() => GroupsCompanion(
    id: Value(id ?? ''),
    name: Value(name ?? ''),
    amount: Value(amount ?? 0),
    potAmount: Value(potAmount),
    periodType: Value(periodType ?? ''),
    totalSlots: Value(totalSlots ?? 0),
    filledSlots: Value(filledSlots ?? 0),
    drawMethod: Value(drawMethod),
    startDate: Value(startDate),
    reminderDaysBefore: Value(reminderDaysBefore),
    status: Value(status ?? ''),
    myRole: Value(myRole ?? ''),
    myMemberId: Value(myMemberId),
    organizerId: Value(organizer?.id),
    organizerName: Value(organizer?.name),
    organizerAvatarUrl: Value(organizer?.avatarUrl),
    inviteCode: Value(invite?.inviteCode),
    inviteUrl: Value(invite?.inviteUrl),
    bankName: Value(paymentInfo?.bankName),
    bankAccountNumber: Value(paymentInfo?.accountNumber),
    bankAccountHolder: Value(paymentInfo?.accountHolder),
    qrisMerchantName: Value(paymentInfo?.qrisMerchantName),
    hasQris: Value(paymentInfo?.qrisImageUrl != null),
    currentPeriodId: Value(currentPeriodId),
    startedAt: Value(startedAt),
    completedAt: Value(completedAt),
    closedAt: Value(closedAt),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );
}

extension GroupSummaryModelMapper on GroupSummaryModel {
  GroupSummary toEntity() => GroupSummary(
    id: id,
    name: name,
    amount: amount,
    periodType: PeriodType.fromApi(periodType),
    status: GroupStatus.fromApi(status),
    myRole: MemberRole.fromApi(myRole),
    totalSlots: totalSlots,
    filledSlots: filledSlots,
    currentPeriodNo: currentPeriodNo,
    nextDueDate: parseBusinessDate(nextDueDate),
    nextDrawDate: parseBusinessDate(nextDrawDate),
    myPaymentStatus: _paymentStatus(myPaymentStatus),
    paidCount: paidCount,
    pendingReviewCount: pendingReviewCount,
    iHaveWon: iHaveWon,
  );

  /// The summary columns only; detail-only columns stay absent.
  GroupsCompanion toCompanion() => GroupsCompanion(
    id: Value(id ?? ''),
    name: Value(name ?? ''),
    amount: Value(amount ?? 0),
    periodType: Value(periodType ?? ''),
    status: Value(status ?? ''),
    myRole: Value(myRole ?? ''),
    totalSlots: Value(totalSlots ?? 0),
    filledSlots: Value(filledSlots ?? 0),
    currentPeriodNo: Value(currentPeriodNo),
    nextDueDate: Value(nextDueDate),
    nextDrawDate: Value(nextDrawDate),
    myPaymentStatus: Value(myPaymentStatus),
    paidCount: Value(paidCount),
    pendingReviewCount: Value(pendingReviewCount),
    iHaveWon: Value(iHaveWon),
  );
}

extension GroupRowMapper on GroupRow {
  GroupDetail toGroup() => GroupDetail(
    id: id,
    name: name,
    amount: amount,
    potAmount: potAmount,
    periodType: PeriodType.fromApi(periodType),
    totalSlots: totalSlots,
    filledSlots: filledSlots,
    drawMethod: DrawMethod.fromApi(drawMethod),
    startDate: parseBusinessDate(startDate),
    reminderDaysBefore: reminderDaysBefore,
    status: GroupStatus.fromApi(status),
    organizer: organizerId == null && organizerName == null
        ? null
        : UserSummary(id: organizerId, name: organizerName, avatarUrl: organizerAvatarUrl),
    myRole: MemberRole.fromApi(myRole),
    myMemberId: myMemberId,
    invite: inviteCode == null ? null : Invite(code: inviteCode, url: inviteUrl),
    paymentInfo: PaymentInfo(
      bankName: bankName,
      accountNumber: bankAccountNumber,
      accountHolder: bankAccountHolder,
      qrisMerchantName: qrisMerchantName,
      hasQris: hasQris,
    ),
    currentPeriodId: currentPeriodId,
    startedAt: startedAt,
    completedAt: completedAt,
    closedAt: closedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    currentPeriodNo: currentPeriodNo,
    nextDueDate: parseBusinessDate(nextDueDate),
    nextDrawDate: parseBusinessDate(nextDrawDate),
    myPaymentStatus: _paymentStatus(myPaymentStatus),
    paidCount: paidCount,
    pendingReviewCount: pendingReviewCount,
    iHaveWon: iHaveWon,
  );

  GroupSummary toSummary() => GroupSummary(
    id: id,
    name: name,
    amount: amount,
    periodType: PeriodType.fromApi(periodType),
    status: GroupStatus.fromApi(status),
    myRole: MemberRole.fromApi(myRole),
    totalSlots: totalSlots,
    filledSlots: filledSlots,
    currentPeriodNo: currentPeriodNo,
    nextDueDate: parseBusinessDate(nextDueDate),
    nextDrawDate: parseBusinessDate(nextDrawDate),
    myPaymentStatus: _paymentStatus(myPaymentStatus),
    paidCount: paidCount,
    pendingReviewCount: pendingReviewCount,
    iHaveWon: iHaveWon,
  );
}

extension CreateGroupInputMapper on CreateGroupInput {
  CreateGroupRequestModel toRequest() => CreateGroupRequestModel(
    name: name.trim(),
    amount: amount,
    periodType: periodType.apiValue,
    totalSlots: totalSlots,
    startDate: formatBusinessDate(startDate),
    drawMethod: drawMethod.apiValue,
    reminderDaysBefore: reminderDaysBefore,
  );
}

extension UpdateGroupInputMapper on UpdateGroupInput {
  UpdateGroupRequestModel toRequest() => UpdateGroupRequestModel(
    name: name?.trim(),
    amount: amount,
    periodType: periodType?.apiValue,
    totalSlots: totalSlots,
    startDate: startDate == null ? null : formatBusinessDate(startDate!),
    drawMethod: drawMethod?.apiValue,
    reminderDaysBefore: reminderDaysBefore,
  );
}

extension PaymentInfoInputMapper on PaymentInfoInput {
  PaymentInfoRequestModel toRequest() => PaymentInfoRequestModel(
    bankName: bankName.trim(),
    accountNumber: accountNumber.replaceAll(RegExp(r'\D'), ''),
    accountHolder: accountHolder.trim(),
  );
}
