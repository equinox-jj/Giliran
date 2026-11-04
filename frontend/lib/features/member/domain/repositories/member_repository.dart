import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../group/domain/entities/group.dart';
import '../entities/claim_link.dart';
import '../entities/invite_preview.dart';
import '../entities/leave_request.dart';
import '../entities/member.dart';
import '../entities/member_input.dart';
import '../entities/obligation.dart';
import '../entities/ownership_transfer.dart';

/// Group membership: members and guests, invites, claims, leave requests,
/// ownership transfers, the fixed order and starting a group. Members are
/// cached (screens watch the cache and ask for a refresh, server wins);
/// previews, obligations, requests and transfers are fetched live. Writes
/// that change the group also refresh its cached row.
abstract interface class MemberRepository() {
  /// A group's cached members by slot number.
  Stream<Either<Failure, List<Member>>> watchMembers(String groupId);

  /// `GET /members` into the cache.
  Future<Either<Failure, Unit>> refreshMembers(String groupId);

  /// One cached member; `null` until fetched or once gone.
  Stream<Either<Failure, Member?>> watchMember(String memberId);

  /// `GET /members/{mid}` into the cache.
  Future<Either<Failure, Member>> getMember(String groupId, String memberId);

  Future<Either<Failure, InvitePreview>> getInvitePreview(String code);

  /// Joins and caches the group. The member carries the group id.
  Future<Either<Failure, Member>> joinGroup(String code);

  Future<Either<Failure, Invite>> resetInviteCode(String groupId);

  Future<Either<Failure, Member>> addGuest(String groupId, GuestInput input);

  Future<Either<Failure, Member>> updateGuest(String groupId, String memberId, UpdateGuestInput input);

  Future<Either<Failure, Unit>> removeMember(String groupId, String memberId);

  Future<Either<Failure, ClaimLink>> createClaimLink(String groupId, String memberId);

  /// Claims a guest slot. Returns the id of the group the slot is in, or
  /// `null` when it can't be told from the group list.
  Future<Either<Failure, String?>> claimSlot(String token);

  Future<Either<Failure, List<LeaveRequest>>> getLeaveRequests(String groupId, {String? status});

  Future<Either<Failure, LeaveRequest>> requestLeave(String groupId, {String? reason});

  Future<Either<Failure, LeaveRequest>> approveLeave(String groupId, String requestId);

  Future<Either<Failure, LeaveRequest>> rejectLeave(String groupId, String requestId, {String? reason});

  Future<Either<Failure, OwnershipTransfer>> offerTransfer(String groupId, String toMemberId);

  Future<Either<Failure, OwnershipTransfer>> acceptTransfer(String groupId, String transferId);

  Future<Either<Failure, OwnershipTransfer>> declineTransfer(String groupId, String transferId);

  Future<Either<Failure, List<Member>>> saveFixedOrder(String groupId, List<FixedOrderEntry> order);

  Future<Either<Failure, GroupDetail>> startGroup(String groupId);

  Future<Either<Failure, List<Obligation>>> getObligations(String groupId);
}
