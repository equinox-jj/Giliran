import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/claim_link.dart';
import 'package:giliran/features/member/domain/entities/invite_preview.dart';
import 'package:giliran/features/member/domain/entities/leave_request.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/entities/member_input.dart';
import 'package:giliran/features/member/domain/entities/obligation.dart';
import 'package:giliran/features/member/domain/entities/ownership_transfer.dart';
import 'package:giliran/features/member/domain/repositories/member_repository.dart';

/// Records each call and answers with the configured results. [watchMembers]
/// starts with [members] and re-emits on [emitMembers].
class FakeMemberRepository() implements MemberRepository {
  final calls = <String>[];
  List<FixedOrderEntry>? lastOrder;
  GuestInput? lastGuest;
  UpdateGuestInput? lastGuestUpdate;
  String? lastReason;
  String? lastLeaveStatus;
  String? lastTransferTarget;

  List<Member> members = [];
  Member? member;
  List<Obligation> obligations = [];
  List<LeaveRequest> leaveRequests = [];

  Either<Failure, Unit> refreshResult = const Right(unit);
  Either<Failure, InvitePreview> previewResult = const Right(
    InvitePreview(groupId: 'g1', groupName: 'Arisan RT 05'),
  );
  Either<Failure, Member> memberResult = const Right(Member(id: 'm9', groupId: 'g1'));
  Either<Failure, Invite> inviteResult = const Right(
    Invite(code: 'AB12CD34', url: 'https://giliran.monai.my.id/j/AB12CD34'),
  );
  Either<Failure, Unit> removeResult = const Right(unit);
  Either<Failure, ClaimLink> claimLinkResult = Right(
    ClaimLink(url: 'https://giliran.monai.my.id/c/${'a' * 32}', expiresAt: DateTime.utc(2026, 11, 11)),
  );
  Either<Failure, String?> claimResult = const Right('g1');
  Either<Failure, LeaveRequest> leaveResult = const Right(LeaveRequest(id: 'r1'));
  Either<Failure, OwnershipTransfer> transferResult = const Right(OwnershipTransfer(id: 't1'));
  Either<Failure, List<Member>>? fixedOrderResult;
  Either<Failure, GroupDetail> startResult = const Right(GroupDetail(id: 'g1'));
  Either<Failure, List<Obligation>>? obligationsResult;
  Either<Failure, List<LeaveRequest>>? leaveRequestsResult;

  final _members = StreamController<List<Member>>.broadcast();
  final _member = StreamController<Member?>.broadcast();

  void emitMembers(List<Member> value) {
    members = value;
    _members.add(value);
  }

  void emitMember(Member? value) {
    member = value;
    _member.add(value);
  }

  @override
  Stream<Either<Failure, List<Member>>> watchMembers(String groupId) async* {
    yield Right(members);
    yield* _members.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, Unit>> refreshMembers(String groupId) async {
    calls.add('refreshMembers');
    return refreshResult;
  }

  @override
  Stream<Either<Failure, Member?>> watchMember(String memberId) async* {
    yield Right(member);
    yield* _member.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, Member>> getMember(String groupId, String memberId) async {
    calls.add('getMember');
    return memberResult;
  }

  @override
  Future<Either<Failure, InvitePreview>> getInvitePreview(String code) async {
    calls.add('getInvitePreview:$code');
    return previewResult;
  }

  @override
  Future<Either<Failure, Member>> joinGroup(String code) async {
    calls.add('joinGroup:$code');
    return memberResult;
  }

  @override
  Future<Either<Failure, Invite>> resetInviteCode(String groupId) async {
    calls.add('resetInviteCode');
    return inviteResult;
  }

  @override
  Future<Either<Failure, Member>> addGuest(String groupId, GuestInput input) async {
    calls.add('addGuest');
    lastGuest = input;
    return memberResult;
  }

  @override
  Future<Either<Failure, Member>> updateGuest(String groupId, String memberId, UpdateGuestInput input) async {
    calls.add('updateGuest');
    lastGuestUpdate = input;
    return memberResult;
  }

  @override
  Future<Either<Failure, Unit>> removeMember(String groupId, String memberId) async {
    calls.add('removeMember:$memberId');
    return removeResult;
  }

  @override
  Future<Either<Failure, ClaimLink>> createClaimLink(String groupId, String memberId) async {
    calls.add('createClaimLink');
    return claimLinkResult;
  }

  @override
  Future<Either<Failure, String?>> claimSlot(String token) async {
    calls.add('claimSlot');
    return claimResult;
  }

  @override
  Future<Either<Failure, List<LeaveRequest>>> getLeaveRequests(String groupId, {String? status}) async {
    calls.add('getLeaveRequests');
    lastLeaveStatus = status;
    return leaveRequestsResult ?? Right(leaveRequests);
  }

  @override
  Future<Either<Failure, LeaveRequest>> requestLeave(String groupId, {String? reason}) async {
    calls.add('requestLeave');
    lastReason = reason;
    return leaveResult;
  }

  @override
  Future<Either<Failure, LeaveRequest>> approveLeave(String groupId, String requestId) async {
    calls.add('approveLeave:$requestId');
    return leaveResult;
  }

  @override
  Future<Either<Failure, LeaveRequest>> rejectLeave(String groupId, String requestId, {String? reason}) async {
    calls.add('rejectLeave:$requestId');
    lastReason = reason;
    return leaveResult;
  }

  @override
  Future<Either<Failure, OwnershipTransfer>> offerTransfer(String groupId, String toMemberId) async {
    calls.add('offerTransfer');
    lastTransferTarget = toMemberId;
    return transferResult;
  }

  @override
  Future<Either<Failure, OwnershipTransfer>> acceptTransfer(String groupId, String transferId) async {
    calls.add('acceptTransfer');
    return transferResult;
  }

  @override
  Future<Either<Failure, OwnershipTransfer>> declineTransfer(String groupId, String transferId) async {
    calls.add('declineTransfer');
    return transferResult;
  }

  @override
  Future<Either<Failure, List<Member>>> saveFixedOrder(String groupId, List<FixedOrderEntry> order) async {
    calls.add('saveFixedOrder');
    lastOrder = order;
    return fixedOrderResult ?? Right(members);
  }

  @override
  Future<Either<Failure, GroupDetail>> startGroup(String groupId) async {
    calls.add('startGroup');
    return startResult;
  }

  @override
  Future<Either<Failure, List<Obligation>>> getObligations(String groupId) async {
    calls.add('getObligations');
    return obligationsResult ?? Right(obligations);
  }
}
