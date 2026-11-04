import '../../../group/data/datasource/model/group_model.dart';
import 'model/claim_link_model.dart';
import 'model/invite_preview_model.dart';
import 'model/leave_request_model.dart';
import 'model/member_model.dart';
import 'model/member_request_model.dart';
import 'model/obligation_model.dart';
import 'model/ownership_transfer_model.dart';

/// The member, invite, guest, leave and ownership endpoints of the API.
abstract interface class MemberRemoteDataSource() {
  /// `GET /groups/{id}/members` (active members, by slot number).
  Future<List<MemberModel>> listMembers(String groupId);

  /// `GET /groups/{id}/members/{mid}`.
  Future<MemberModel> getMember(String groupId, String memberId);

  /// `GET /invites/{code}`.
  Future<InvitePreviewModel> getInvitePreview(String code);

  /// `POST /invites/{code}/join`. Returns the new member and the group id
  /// from the `Location` header.
  Future<({MemberModel member, String? groupId})> joinGroup(String code);

  /// `POST /groups/{id}/invite-code/reset`.
  Future<InviteModel> resetInviteCode(String groupId);

  /// `POST /groups/{id}/guests`.
  Future<MemberModel> addGuest(String groupId, GuestRequestModel body);

  /// `PATCH /groups/{id}/members/{mid}` with [body] as is, so a `null`
  /// phone clears it.
  Future<MemberModel> updateGuest(String groupId, String memberId, Map<String, Object?> body);

  /// `DELETE /groups/{id}/members/{mid}`.
  Future<void> removeMember(String groupId, String memberId);

  /// `POST /groups/{id}/members/{mid}/claim-link`.
  Future<ClaimLinkModel> createClaimLink(String groupId, String memberId);

  /// `POST /claims/{token}`.
  Future<MemberModel> claimSlot(String token);

  /// `GET /groups/{id}/leave-requests`, newest first, optionally filtered by
  /// [status].
  Future<List<LeaveRequestModel>> listLeaveRequests(String groupId, {String? status});

  /// `POST /groups/{id}/leave-requests`.
  Future<LeaveRequestModel> requestLeave(String groupId, {String? reason});

  /// `POST /groups/{id}/leave-requests/{rid}/approve`.
  Future<LeaveRequestModel> approveLeave(String groupId, String requestId);

  /// `POST /groups/{id}/leave-requests/{rid}/reject`.
  Future<LeaveRequestModel> rejectLeave(String groupId, String requestId, {String? reason});

  /// `POST /groups/{id}/ownership-transfers`.
  Future<OwnershipTransferModel> offerTransfer(String groupId, String toMemberId);

  /// `POST /groups/{id}/ownership-transfers/{tid}/accept`.
  Future<OwnershipTransferModel> acceptTransfer(String groupId, String transferId);

  /// `POST /groups/{id}/ownership-transfers/{tid}/decline`.
  Future<OwnershipTransferModel> declineTransfer(String groupId, String transferId);

  /// `PUT /groups/{id}/fixed-order`. Returns every member with its
  /// position.
  Future<List<MemberModel>> saveFixedOrder(String groupId, FixedOrderRequestModel body);

  /// `POST /groups/{id}/start`.
  Future<GroupModel> startGroup(String groupId);

  /// `GET /groups/{id}/obligations`, most overdue first.
  Future<List<ObligationModel>> listObligations(String groupId);
}
