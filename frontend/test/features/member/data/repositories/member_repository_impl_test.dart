import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/datasource/group_local_data_source_impl.dart';
import 'package:giliran/features/group/data/datasource/group_remote_data_source.dart';
import 'package:giliran/features/group/data/datasource/model/group_model.dart';
import 'package:giliran/features/group/data/datasource/model/group_request_model.dart';
import 'package:giliran/features/group/data/datasource/model/group_summary_model.dart';
import 'package:giliran/features/member/data/datasource/member_local_data_source_impl.dart';
import 'package:giliran/features/member/data/datasource/member_remote_data_source.dart';
import 'package:giliran/features/member/data/datasource/model/claim_link_model.dart';
import 'package:giliran/features/member/data/datasource/model/invite_preview_model.dart';
import 'package:giliran/features/member/data/datasource/model/leave_request_model.dart';
import 'package:giliran/features/member/data/datasource/model/member_model.dart';
import 'package:giliran/features/member/data/datasource/model/member_request_model.dart';
import 'package:giliran/features/member/data/datasource/model/obligation_model.dart';
import 'package:giliran/features/member/data/datasource/model/ownership_transfer_model.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/member_input.dart';

import '../../../../core/database/fixtures.dart';
import '../../../group/fixtures.dart';
import '../../fixtures.dart';

/// Answers each call with the configured models, or throws [error].
class _FakeRemote() implements MemberRemoteDataSource {
  List<MemberModel> members = [MemberModel.fromJson(memberJson('m1'))];
  String? joinedGroupId = 'g1';
  Object? error;
  final calls = <String>[];

  Future<T> _answer<T>(String name, T value) async {
    calls.add(name);
    if (error case final e?) throw e;
    return value;
  }

  MemberModel get _member => members.first;

  @override
  Future<List<MemberModel>> listMembers(String groupId) => _answer('listMembers', members);

  @override
  Future<MemberModel> getMember(String groupId, String memberId) => _answer('getMember', _member);

  @override
  Future<InvitePreviewModel> getInvitePreview(String code) =>
      _answer('getInvitePreview', InvitePreviewModel.fromJson(invitePreviewJson));

  @override
  Future<({MemberModel member, String? groupId})> joinGroup(String code) =>
      _answer('joinGroup', (member: _member, groupId: joinedGroupId));

  @override
  Future<InviteModel> resetInviteCode(String groupId) =>
      _answer('resetInviteCode', const InviteModel(inviteCode: 'AB12CD34'));

  @override
  Future<MemberModel> addGuest(String groupId, GuestRequestModel body) => _answer('addGuest', _member);

  @override
  Future<MemberModel> updateGuest(String groupId, String memberId, Map<String, Object?> body) =>
      _answer('updateGuest', _member);

  @override
  Future<void> removeMember(String groupId, String memberId) => _answer('removeMember', null);

  @override
  Future<ClaimLinkModel> createClaimLink(String groupId, String memberId) =>
      _answer('createClaimLink', ClaimLinkModel.fromJson(claimLinkJson));

  @override
  Future<MemberModel> claimSlot(String token) => _answer('claimSlot', _member);

  @override
  Future<List<LeaveRequestModel>> listLeaveRequests(String groupId, {String? status}) =>
      _answer('listLeaveRequests', [LeaveRequestModel.fromJson(leaveRequestJson('r1'))]);

  @override
  Future<LeaveRequestModel> requestLeave(String groupId, {String? reason}) =>
      _answer('requestLeave', LeaveRequestModel.fromJson(leaveRequestJson('r1')));

  @override
  Future<LeaveRequestModel> approveLeave(String groupId, String requestId) =>
      _answer('approveLeave', LeaveRequestModel.fromJson(leaveRequestJson('r1', status: 'approved')));

  @override
  Future<LeaveRequestModel> rejectLeave(String groupId, String requestId, {String? reason}) =>
      _answer('rejectLeave', LeaveRequestModel.fromJson(leaveRequestJson('r1', status: 'rejected')));

  @override
  Future<OwnershipTransferModel> offerTransfer(String groupId, String toMemberId) =>
      _answer('offerTransfer', OwnershipTransferModel.fromJson(transferJson('t1')));

  @override
  Future<OwnershipTransferModel> acceptTransfer(String groupId, String transferId) =>
      _answer('acceptTransfer', OwnershipTransferModel.fromJson(transferJson('t1', status: 'accepted')));

  @override
  Future<OwnershipTransferModel> declineTransfer(String groupId, String transferId) =>
      _answer('declineTransfer', OwnershipTransferModel.fromJson(transferJson('t1', status: 'declined')));

  @override
  Future<List<MemberModel>> saveFixedOrder(String groupId, FixedOrderRequestModel body) =>
      _answer('saveFixedOrder', members);

  @override
  Future<GroupModel> startGroup(String groupId) =>
      _answer('startGroup', GroupModel.fromJson({...groupJson, 'id': groupId, 'status': 'active'}));

  @override
  Future<List<ObligationModel>> listObligations(String groupId) =>
      _answer('listObligations', [ObligationModel.fromJson(obligationJson('m3'))]);
}

/// The group endpoints the member repository uses for follow-ups.
class _FakeGroupRemote() implements GroupRemoteDataSource {
  final lists = <List<GroupSummaryModel>>[];
  Object? getGroupError;

  @override
  Future<List<GroupSummaryModel>> listMyGroups(String status) async => lists.removeAt(0);

  @override
  Future<GroupModel> getGroup(String id) async {
    if (getGroupError case final e?) throw e;
    return GroupModel.fromJson({...groupJson, 'id': id});
  }

  @override
  Future<GroupModel> createGroup(CreateGroupRequestModel body) => throw UnimplementedError();

  @override
  Future<GroupModel> updateGroup(String id, UpdateGroupRequestModel body) => throw UnimplementedError();

  @override
  Future<GroupModel> closeGroup(String id) => throw UnimplementedError();

  @override
  Future<GroupModel> updatePaymentInfo(String id, PaymentInfoRequestModel body) => throw UnimplementedError();

  @override
  Future<GroupModel> uploadQris(String id, String path) => throw UnimplementedError();

  @override
  Future<void> deleteQris(String id) => throw UnimplementedError();
}

ConflictException _conflict(ApiErrorCode code) => ConflictException(
  problem: ProblemDetails(status: 409, code: code, rawCode: code.apiValue),
);

NotFoundException _notFound(ApiErrorCode code) => NotFoundException(
  problem: ProblemDetails(status: 404, code: code, rawCode: code.apiValue),
);

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late _FakeGroupRemote groupRemote;
  late MemberRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    remote = _FakeRemote();
    groupRemote = _FakeGroupRemote();
    repository = MemberRepositoryImpl(
      remote,
      MemberLocalDataSourceImpl(db.membersDao),
      groupRemote,
      GroupLocalDataSourceImpl(db.groupsDao),
    );
    await db.groupsDao.upsertAll([groupRow('g1')]);
  });
  tearDown(() => db.close());

  test('refresh writes members the watch stream then emits', () async {
    // Arrange
    remote.members = [
      MemberModel.fromJson(memberJson('m1', role: 'organizer')),
      MemberModel.fromJson(memberJson('m2', slotNo: 2, isGuest: true, name: 'Bu Sri')),
    ];

    // Act
    await repository.refreshMembers('g1');

    // Assert
    final members = (await repository.watchMembers('g1').first).getOrElse((_) => []);
    expect(members.map((m) => m.id), ['m1', 'm2']);
    expect(members.first.role, MemberRole.organizer);
    expect(members.last.isGuest, isTrue);
    expect(members.last.groupId, 'g1');
  });

  test('a refresh drops cached members the server no longer returns', () async {
    // Arrange
    await db.membersDao.upsertAll([memberRow('gone', 'g1', 5)]);

    // Act
    await repository.refreshMembers('g1');

    // Assert
    final members = (await repository.watchMembers('g1').first).getOrElse((_) => []);
    expect(members.map((m) => m.id), ['m1']);
  });

  test('joining caches the group before its member', () async {
    // Arrange
    remote.joinedGroupId = 'g2';

    // Act
    final result = await repository.joinGroup('K7P2QX9M');

    // Assert
    expect(result.getOrElse((_) => throw StateError('failed')).groupId, 'g2');
    expect(await db.groupsDao.watchById('g2').first, isNotNull);
    expect((await db.membersDao.watchByGroup('g2').first).single.id, 'm1');
  });

  test('a failed follow-up group fetch does not fail the join', () async {
    // Arrange
    groupRemote.getGroupError = const NetworkException();

    // Act
    final result = await repository.joinGroup('K7P2QX9M');

    // Assert
    expect(result.isRight(), isTrue);
  });

  test('removing a member drops it from the cache', () async {
    // Arrange
    await db.membersDao.upsertAll([memberRow('m4', 'g1', 4)]);

    // Act
    await repository.removeMember('g1', 'm4');

    // Assert
    expect(await db.membersDao.watchById('m4').first, isNull);
  });

  test('claimSlot returns the group that appeared after the claim', () async {
    // Arrange
    groupRemote.lists.addAll([
      [GroupSummaryModel.fromJson(summaryJson('g1'))],
      [GroupSummaryModel.fromJson(summaryJson('g1')), GroupSummaryModel.fromJson(summaryJson('g9'))],
    ]);

    // Act
    final result = await repository.claimSlot('a' * 32);

    // Assert
    expect(result, const Right<Failure, String?>('g9'));
    expect(await db.groupsDao.watchById('g9').first, isNotNull);
  });

  test('startGroup caches the active group', () async {
    // Act
    await repository.startGroup('g1');

    // Assert
    expect((await db.groupsDao.watchById('g1').first)?.status, 'active');
  });

  group('maps API codes to failures', () {
    final cases = <String, (Object, Future<Either<Failure, Object?>> Function(MemberRepositoryImpl))>{
      'group_full': (_conflict(ApiErrorCode.groupFull), (r) => r.addGuest('g1', const GuestInput(name: 'Sri'))),
      'already_member': (_conflict(ApiErrorCode.alreadyMember), (r) => r.joinGroup('K7P2QX9M')),
      'obligations_outstanding': (
        _conflict(ApiErrorCode.obligationsOutstanding),
        (r) => r.removeMember('g1', 'm3'),
      ),
      'organizer_cannot_leave': (_conflict(ApiErrorCode.organizerCannotLeave), (r) => r.requestLeave('g1')),
      'pending_request_exists': (_conflict(ApiErrorCode.pendingRequestExists), (r) => r.requestLeave('g1')),
      'claim_not_found': (_notFound(ApiErrorCode.claimNotFound), (r) => r.claimSlot('a' * 32)),
      'invite_not_found': (_notFound(ApiErrorCode.inviteNotFound), (r) => r.getInvitePreview('K7P2QX9M')),
    };
    for (final MapEntry(key: code, value: (error, call)) in cases.entries) {
      test(code, () async {
        // Arrange
        remote.error = error;
        groupRemote.lists.add([]);

        // Act
        final result = await call(repository);

        // Assert
        expect(result.getLeft().toNullable()?.apiCode?.apiValue, code);
      });
    }
  });
}
