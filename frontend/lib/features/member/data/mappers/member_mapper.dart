import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/leave_request_status.dart';
import '../../../../core/utils/enums/member_role.dart';
import '../../../../core/utils/enums/member_status.dart';
import '../../../../core/utils/enums/period_type.dart';
import '../../../../core/utils/enums/transfer_status.dart';
import '../../../group/data/datasource/model/group_model.dart';
import '../../../group/data/mappers/group_mapper.dart';
import '../../../group/domain/entities/group.dart';
import '../../domain/entities/claim_link.dart';
import '../../domain/entities/invite_preview.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/member_input.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/ownership_transfer.dart';
import '../datasource/model/claim_link_model.dart';
import '../datasource/model/invite_preview_model.dart';
import '../datasource/model/leave_request_model.dart';
import '../datasource/model/member_model.dart';
import '../datasource/model/member_request_model.dart';
import '../datasource/model/obligation_model.dart';
import '../datasource/model/ownership_transfer_model.dart';

UserSummary? _user(UserSummaryModel? model) =>
    model == null ? null : UserSummary(id: model.id, name: model.name, avatarUrl: model.avatarUrl);

extension MemberModelMapper on MemberModel {
  Member toEntity({String? groupId}) => Member(
    id: id,
    groupId: groupId,
    user: _user(user),
    displayName: displayName,
    isGuest: isGuest,
    guestPhone: guestPhone,
    role: MemberRole.fromApi(role),
    status: MemberStatus.fromApi(status),
    slotId: slotId,
    slotNo: slotNo,
    fixedOrderPosition: fixedOrderPosition,
    hasWon: hasWon,
    wonPeriodNo: wonPeriodNo,
    joinedAt: joinedAt,
  );

  MembersCompanion toCompanion(String groupId) => MembersCompanion(
    id: Value(id ?? ''),
    groupId: Value(groupId),
    userId: Value(user?.id),
    displayName: Value(displayName ?? ''),
    avatarUrl: Value(user?.avatarUrl),
    isGuest: Value(isGuest ?? false),
    guestPhone: Value(guestPhone),
    role: Value(role ?? ''),
    status: Value(status ?? ''),
    slotId: Value(slotId ?? ''),
    slotNo: Value(slotNo ?? 0),
    fixedOrderPosition: Value(fixedOrderPosition),
    hasWon: Value(hasWon ?? false),
    wonPeriodNo: Value(wonPeriodNo),
    joinedAt: Value(joinedAt ?? DateTime.now().toUtc()),
  );
}

extension MemberRowMapper on MemberRow {
  Member toEntity() => Member(
    id: id,
    groupId: groupId,
    // The cache keeps only the user id and avatar; the name is the
    // member's display name.
    user: userId == null ? null : UserSummary(id: userId, name: displayName, avatarUrl: avatarUrl),
    displayName: displayName,
    isGuest: isGuest,
    guestPhone: guestPhone,
    role: MemberRole.fromApi(role),
    status: MemberStatus.fromApi(status),
    slotId: slotId,
    slotNo: slotNo,
    fixedOrderPosition: fixedOrderPosition,
    hasWon: hasWon,
    wonPeriodNo: wonPeriodNo,
    joinedAt: joinedAt,
  );
}

extension MemberRefModelMapper on MemberRefModel {
  MemberRef toEntity() => MemberRef(
    id: id,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isGuest: isGuest,
    slotNo: slotNo,
  );
}

extension InvitePreviewModelMapper on InvitePreviewModel {
  InvitePreview toEntity() => InvitePreview(
    groupId: groupId,
    groupName: groupName,
    organizer: _user(organizer),
    amount: amount,
    periodType: PeriodType.fromApi(periodType),
    totalSlots: totalSlots,
    filledSlots: filledSlots,
    startDate: parseBusinessDate(startDate),
    status: GroupStatus.fromApi(status),
    canJoin: canJoin,
    alreadyMember: alreadyMember,
  );
}

extension InviteModelMapper on InviteModel {
  Invite toEntity() => Invite(code: inviteCode, url: inviteUrl);
}

extension ClaimLinkModelMapper on ClaimLinkModel {
  ClaimLink toEntity() => ClaimLink(url: claimUrl, expiresAt: expiresAt);
}

extension LeaveRequestModelMapper on LeaveRequestModel {
  LeaveRequest toEntity() => LeaveRequest(
    id: id,
    member: member?.toEntity(),
    reason: reason,
    status: LeaveRequestStatus.fromApi(status),
    reviewedBy: _user(reviewedBy),
    reviewedAt: reviewedAt,
    createdAt: createdAt,
  );
}

extension OwnershipTransferModelMapper on OwnershipTransferModel {
  OwnershipTransfer toEntity() => OwnershipTransfer(
    id: id,
    fromUser: _user(fromUser),
    toMember: toMember?.toEntity(),
    status: TransferStatus.fromApi(status),
    expiresAt: expiresAt,
    respondedAt: respondedAt,
    createdAt: createdAt,
  );
}

extension ObligationModelMapper on ObligationModel {
  Obligation toEntity() => Obligation(
    member: member?.toEntity(),
    wonPeriodNo: wonPeriodNo,
    remainingCount: remainingCount,
    remainingAmount: remainingAmount,
    overdueCount: overdueCount,
    overdueAmount: overdueAmount,
  );
}

extension GuestInputMapper on GuestInput {
  GuestRequestModel toRequest() {
    final trimmed = phone?.trim();
    return GuestRequestModel(name: name.trim(), phone: trimmed == null || trimmed.isEmpty ? null : trimmed);
  }
}

extension UpdateGuestInputMapper on UpdateGuestInput {
  /// The PATCH body: only the changed fields, with `phone: null` to clear.
  Map<String, Object?> toBody() => {
    if (name != null) 'name': name!.trim(),
    if (clearPhone) 'phone': null else if (phone != null) 'phone': phone!.trim(),
  };
}

extension FixedOrderMapper on List<FixedOrderEntry> {
  FixedOrderRequestModel toRequest() => FixedOrderRequestModel(
    order: [for (final e in this) FixedOrderItemModel(slotId: e.slotId, position: e.position)],
  );
}
