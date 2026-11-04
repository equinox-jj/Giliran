import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_remote_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../group/data/datasource/model/group_model.dart';
import 'member_remote_data_source.dart';
import 'model/claim_link_model.dart';
import 'model/invite_preview_model.dart';
import 'model/leave_request_model.dart';
import 'model/member_model.dart';
import 'model/member_request_model.dart';
import 'model/obligation_model.dart';
import 'model/ownership_transfer_model.dart';

part 'member_remote_data_source_impl.g.dart';

typedef _Json = Map<String, dynamic>;

class MemberRemoteDataSourceImpl(final Dio _dio) with BaseRemoteDataSource implements MemberRemoteDataSource {
  @override
  Future<List<MemberModel>> listMembers(String groupId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(
      ApiEndpoints.members(groupId),
      queryParameters: {'status': 'active'},
    );
    return _list(response, MemberModel.fromJson);
  });

  @override
  Future<MemberModel> getMember(String groupId, String memberId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.member(groupId, memberId));
    return _one(response, MemberModel.fromJson);
  });

  @override
  Future<InvitePreviewModel> getInvitePreview(String code) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.invite(code));
    return _one(response, InvitePreviewModel.fromJson);
  });

  @override
  Future<({MemberModel member, String? groupId})> joinGroup(String code) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.inviteJoin(code));
    return (
      member: _one(response, MemberModel.fromJson),
      groupId: groupIdFromLocation(response.headers.value('location')),
    );
  });

  @override
  Future<InviteModel> resetInviteCode(String groupId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.inviteReset(groupId));
    return _one(response, InviteModel.fromJson);
  });

  @override
  Future<MemberModel> addGuest(String groupId, GuestRequestModel body) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.guests(groupId), data: body.toJson());
    return _one(response, MemberModel.fromJson);
  });

  @override
  Future<MemberModel> updateGuest(String groupId, String memberId, Map<String, Object?> body) => safeApiCall(() async {
    final response = await _dio.patch<_Json>(ApiEndpoints.member(groupId, memberId), data: body);
    return _one(response, MemberModel.fromJson);
  });

  @override
  Future<void> removeMember(String groupId, String memberId) => safeApiCall(() async {
    await _dio.delete<void>(ApiEndpoints.member(groupId, memberId));
  });

  @override
  Future<ClaimLinkModel> createClaimLink(String groupId, String memberId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.claimLink(groupId, memberId));
    return _one(response, ClaimLinkModel.fromJson);
  });

  @override
  Future<MemberModel> claimSlot(String token) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.claim(token));
    return _one(response, MemberModel.fromJson);
  });

  @override
  Future<List<LeaveRequestModel>> listLeaveRequests(String groupId, {String? status}) => safeApiCall(() async {
    final response = await _dio.get<_Json>(
      ApiEndpoints.leaveRequests(groupId),
      queryParameters: {'status': ?status},
    );
    return _list(response, LeaveRequestModel.fromJson);
  });

  @override
  Future<LeaveRequestModel> requestLeave(String groupId, {String? reason}) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.leaveRequests(groupId),
      data: {'reason': ?reason},
    );
    return _one(response, LeaveRequestModel.fromJson);
  });

  @override
  Future<LeaveRequestModel> approveLeave(String groupId, String requestId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.leaveApprove(groupId, requestId));
    return _one(response, LeaveRequestModel.fromJson);
  });

  @override
  Future<LeaveRequestModel> rejectLeave(String groupId, String requestId, {String? reason}) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.leaveReject(groupId, requestId),
      data: {'reason': ?reason},
    );
    return _one(response, LeaveRequestModel.fromJson);
  });

  @override
  Future<OwnershipTransferModel> offerTransfer(String groupId, String toMemberId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(
      ApiEndpoints.ownershipTransfers(groupId),
      data: {'to_member_id': toMemberId},
    );
    return _one(response, OwnershipTransferModel.fromJson);
  });

  @override
  Future<OwnershipTransferModel> acceptTransfer(String groupId, String transferId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.transferAccept(groupId, transferId));
    return _one(response, OwnershipTransferModel.fromJson);
  });

  @override
  Future<OwnershipTransferModel> declineTransfer(String groupId, String transferId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.transferDecline(groupId, transferId));
    return _one(response, OwnershipTransferModel.fromJson);
  });

  @override
  Future<List<MemberModel>> saveFixedOrder(String groupId, FixedOrderRequestModel body) => safeApiCall(() async {
    final response = await _dio.put<_Json>(ApiEndpoints.fixedOrder(groupId), data: body.toJson());
    return _list(response, MemberModel.fromJson);
  });

  @override
  Future<GroupModel> startGroup(String groupId) => safeApiCall(() async {
    final response = await _dio.post<_Json>(ApiEndpoints.groupStart(groupId));
    return _one(response, GroupModel.fromJson);
  });

  @override
  Future<List<ObligationModel>> listObligations(String groupId) => safeApiCall(() async {
    final response = await _dio.get<_Json>(ApiEndpoints.obligations(groupId));
    return _list(response, ObligationModel.fromJson);
  });

  /// The group id in a member `Location` such as
  /// `/api/v1/groups/{gid}/members/{mid}`.
  static String? groupIdFromLocation(String? location) {
    if (location == null) return null;
    final segments = Uri.tryParse(location)?.pathSegments ?? const <String>[];
    final index = segments.indexOf('groups');
    return index >= 0 && index + 1 < segments.length ? segments[index + 1] : null;
  }

  static T _one<T>(Response<_Json> response, T Function(_Json) parse) {
    final data = response.data?['data'];
    if (data is! _Json) throw UnknownException('Empty ${response.requestOptions.path} response');
    return parse(data);
  }

  static List<T> _list<T>(Response<_Json> response, T Function(_Json) parse) {
    final data = response.data?['data'];
    if (data is! List) throw UnknownException('Empty ${response.requestOptions.path} response');
    return [for (final item in data) parse(item as _Json)];
  }
}

@Riverpod(keepAlive: true)
MemberRemoteDataSource memberRemoteDataSource(Ref ref) => MemberRemoteDataSourceImpl(ref.watch(dioProvider));
