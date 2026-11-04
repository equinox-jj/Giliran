import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/enums/payment_method.dart';
import '../../../../core/utils/enums/payment_status.dart';
import '../../../../core/utils/enums/period_status.dart';
import '../../../group/data/datasource/model/group_model.dart';
import '../../../group/data/mappers/group_mapper.dart';
import '../../../group/domain/entities/group.dart';
import '../../../member/data/mappers/member_mapper.dart';
import '../../../member/domain/entities/member.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/period.dart';
import '../datasource/model/payment_model.dart';
import '../datasource/model/payout_model.dart';
import '../datasource/model/period_model.dart';

UserSummary? _user(UserSummaryModel? model) =>
    model == null ? null : UserSummary(id: model.id, name: model.name, avatarUrl: model.avatarUrl);

PaymentStatus? _status(String? value) => value == null ? null : PaymentStatus.fromApi(value);

extension PaymentProofModelMapper on PaymentProofModel {
  PaymentProof toEntity() => PaymentProof(id: id, url: url, contentType: contentType, uploadedAt: uploadedAt);
}

extension PaymentSummaryModelMapper on PaymentSummaryModel {
  PaymentSummary toEntity() => PaymentSummary(
    totalCount: totalCount,
    paidCount: paidCount,
    pendingReviewCount: pendingReviewCount,
    unpaidCount: unpaidCount,
    rejectedCount: rejectedCount,
    collectedAmount: collectedAmount,
    expectedAmount: expectedAmount,
  );
}

extension PaymentModelMapper on PaymentModel {
  Payment toEntity({String? groupId}) => Payment(
    id: id,
    groupId: groupId,
    periodId: periodId,
    member: member?.toEntity(),
    amount: amount,
    status: _status(status),
    method: PaymentMethod.fromApi(method),
    currentProof: currentProof?.toEntity(),
    note: note,
    rejectReason: rejectReason,
    paidAt: paidAt,
    reviewedBy: _user(reviewedBy),
    reviewedAt: reviewedAt,
    isMine: isMine,
    updatedAt: updatedAt,
    proofs: proofs == null ? null : [for (final p in proofs!) p.toEntity()],
    pendingSync: false,
  );

  PaymentsCompanion toCompanion(String groupId) => PaymentsCompanion(
    id: Value(id ?? ''),
    groupId: Value(groupId),
    periodId: Value(periodId ?? ''),
    memberId: Value(member?.id ?? ''),
    memberDisplayName: Value(member?.displayName ?? ''),
    memberAvatarUrl: Value(member?.avatarUrl),
    memberIsGuest: Value(member?.isGuest ?? false),
    memberSlotNo: Value(member?.slotNo ?? 0),
    amount: Value(amount ?? 0),
    status: Value(status ?? PaymentStatus.unpaid.apiValue),
    method: Value(method),
    currentProofId: Value(currentProof?.id),
    note: Value(note),
    rejectReason: Value(rejectReason),
    paidAt: Value(paidAt),
    reviewedById: Value(reviewedBy?.id),
    reviewedByName: Value(reviewedBy?.name),
    reviewedAt: Value(reviewedAt),
    isMine: Value(isMine ?? false),
    updatedAt: Value(updatedAt ?? DateTime.now().toUtc()),
  );
}

extension PaymentRowMapper on PaymentRow {
  Payment toEntity() => Payment(
    id: id,
    groupId: groupId,
    periodId: periodId,
    member: MemberRef(
      id: memberId,
      displayName: memberDisplayName,
      avatarUrl: memberAvatarUrl,
      isGuest: memberIsGuest,
      slotNo: memberSlotNo,
    ),
    amount: amount,
    status: PaymentStatus.fromApi(status),
    method: PaymentMethod.fromApi(method),
    currentProof: currentProofId == null ? null : PaymentProof(id: currentProofId),
    note: note,
    rejectReason: rejectReason,
    paidAt: paidAt,
    reviewedBy: reviewedById == null ? null : UserSummary(id: reviewedById, name: reviewedByName),
    reviewedAt: reviewedAt,
    isMine: isMine,
    updatedAt: updatedAt,
    pendingSync: pendingSync,
  );
}

extension PeriodModelMapper on PeriodModel {
  Period toEntity({String? groupId}) => Period(
    id: id,
    groupId: groupId,
    periodNo: periodNo,
    dueDate: parseBusinessDate(dueDate),
    drawDate: parseBusinessDate(drawDate),
    status: PeriodStatus.fromApi(status),
    seedHash: seedHash,
    verificationCode: verificationCode,
    drawnAt: drawnAt,
    winner: winner?.toEntity(),
    paymentSummary: paymentSummary?.toEntity(),
    payoutRecorded: payoutRecorded,
    payoutConfirmed: payoutConfirmed,
  );

  PeriodsCompanion toCompanion(String groupId) {
    final s = paymentSummary;
    return PeriodsCompanion(
      id: Value(id ?? ''),
      groupId: Value(groupId),
      periodNo: Value(periodNo ?? 0),
      dueDate: Value(dueDate ?? ''),
      drawDate: Value(drawDate ?? ''),
      status: Value(status ?? PeriodStatus.upcoming.apiValue),
      seedHash: Value(seedHash),
      verificationCode: Value(verificationCode),
      drawnAt: Value(drawnAt),
      winnerMemberId: Value(winner?.id),
      winnerDisplayName: Value(winner?.displayName),
      winnerAvatarUrl: Value(winner?.avatarUrl),
      winnerIsGuest: Value(winner?.isGuest),
      winnerSlotNo: Value(winner?.slotNo),
      summaryTotalCount: Value(s?.totalCount),
      summaryPaidCount: Value(s?.paidCount),
      summaryPendingReviewCount: Value(s?.pendingReviewCount),
      summaryUnpaidCount: Value(s?.unpaidCount),
      summaryRejectedCount: Value(s?.rejectedCount),
      summaryCollectedAmount: Value(s?.collectedAmount),
      summaryExpectedAmount: Value(s?.expectedAmount),
      payoutRecorded: Value(payoutRecorded ?? false),
      payoutConfirmed: Value(payoutConfirmed ?? false),
    );
  }
}

extension PaymentSummaryCompanion on PaymentSummaryModel {
  /// Writes a fresh board summary onto its cached period row.
  PeriodsCompanion toPeriodCompanion() => PeriodsCompanion(
    summaryTotalCount: Value(totalCount),
    summaryPaidCount: Value(paidCount),
    summaryPendingReviewCount: Value(pendingReviewCount),
    summaryUnpaidCount: Value(unpaidCount),
    summaryRejectedCount: Value(rejectedCount),
    summaryCollectedAmount: Value(collectedAmount),
    summaryExpectedAmount: Value(expectedAmount),
  );
}

extension PeriodRowMapper on PeriodRow {
  Period toEntity() => Period(
    id: id,
    groupId: groupId,
    periodNo: periodNo,
    dueDate: parseBusinessDate(dueDate),
    drawDate: parseBusinessDate(drawDate),
    status: PeriodStatus.fromApi(status),
    seedHash: seedHash,
    verificationCode: verificationCode,
    drawnAt: drawnAt,
    winner: winnerMemberId == null
        ? null
        : MemberRef(
            id: winnerMemberId,
            displayName: winnerDisplayName,
            avatarUrl: winnerAvatarUrl,
            isGuest: winnerIsGuest,
            slotNo: winnerSlotNo,
          ),
    paymentSummary: summaryTotalCount == null
        ? null
        : PaymentSummary(
            totalCount: summaryTotalCount,
            paidCount: summaryPaidCount,
            pendingReviewCount: summaryPendingReviewCount,
            unpaidCount: summaryUnpaidCount,
            rejectedCount: summaryRejectedCount,
            collectedAmount: summaryCollectedAmount,
            expectedAmount: summaryExpectedAmount,
          ),
    payoutRecorded: payoutRecorded,
    payoutConfirmed: payoutConfirmed,
  );
}

extension PayoutModelMapper on PayoutModel {
  Payout toEntity() => Payout(
    id: id,
    periodId: periodId,
    winner: winner?.toEntity(),
    amount: amount,
    proofUrl: proofUrl,
    hasProof: proofUrl != null,
    note: note,
    recordedBy: _user(recordedBy),
    recordedAt: recordedAt,
    confirmedAt: confirmedAt,
  );

  PayoutsCompanion toCompanion(String groupId) => PayoutsCompanion(
    id: Value(id ?? ''),
    groupId: Value(groupId),
    periodId: Value(periodId ?? ''),
    winnerMemberId: Value(winner?.id ?? ''),
    winnerDisplayName: Value(winner?.displayName ?? ''),
    winnerAvatarUrl: Value(winner?.avatarUrl),
    winnerSlotNo: Value(winner?.slotNo ?? 0),
    amount: Value(amount ?? 0),
    hasProof: Value(proofUrl != null),
    note: Value(note),
    recordedById: Value(recordedBy?.id ?? ''),
    recordedByName: Value(recordedBy?.name ?? ''),
    recordedAt: Value(recordedAt ?? DateTime.now().toUtc()),
    confirmedAt: Value(confirmedAt),
  );
}

extension PayoutRowMapper on PayoutRow {
  Payout toEntity() => Payout(
    id: id,
    periodId: periodId,
    winner: MemberRef(
      id: winnerMemberId,
      displayName: winnerDisplayName,
      avatarUrl: winnerAvatarUrl,
      slotNo: winnerSlotNo,
    ),
    amount: amount,
    hasProof: hasProof,
    note: note,
    recordedBy: UserSummary(id: recordedById, name: recordedByName),
    recordedAt: recordedAt,
    confirmedAt: confirmedAt,
  );
}
