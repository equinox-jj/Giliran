import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/member/data/datasource/member_remote_data_source_impl.dart';
import 'package:giliran/features/member/data/datasource/model/member_request_model.dart';

import '../../fixtures.dart';

/// Records each request and answers with [body] and [headers].
class _RecordingAdapter() implements HttpClientAdapter {
  Object? body;
  int status = 200;
  Map<String, List<String>> headers = {};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late MemberRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = MemberRemoteDataSourceImpl(dio);
  });

  test('listMembers asks for active members and parses each Member', () async {
    // Arrange
    adapter.body = {
      'data': [
        memberJson('m1', role: 'organizer'),
        memberJson('m2', slotNo: 2, name: 'Pak Dedi', isGuest: true, guestPhone: '+6281234567890'),
      ],
    };

    // Act
    final members = await dataSource.listMembers('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/members');
    expect(adapter.requests.single.queryParameters, {'status': 'active'});
    expect(members.first.role, 'organizer');
    expect(members.first.user?.name, 'Rina Ayu');
    expect(members.last.isGuest, isTrue);
    expect(members.last.user, isNull);
    expect(members.last.guestPhone, '+6281234567890');
    expect(members.last.joinedAt, DateTime.utc(2026, 10, 1, 3));
  });

  test('getInvitePreview parses the InvitePreview', () async {
    // Arrange
    adapter.body = {'data': invitePreviewJson};

    // Act
    final preview = await dataSource.getInvitePreview('K7P2QX9M');

    // Assert
    expect(adapter.requests.single.path, '/invites/K7P2QX9M');
    expect(preview.groupName, 'Arisan RT 05');
    expect(preview.organizer?.name, 'Rina Ayu');
    expect(preview.canJoin, isTrue);
    expect(preview.alreadyMember, isFalse);
  });

  test('joinGroup reads the group id from the Location header', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': memberJson('m9', slotNo: 9)}
      ..headers = {
        'location': ['/api/v1/groups/g1/members/m9'],
      };

    // Act
    final result = await dataSource.joinGroup('K7P2QX9M');

    // Assert
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/invites/K7P2QX9M/join');
    expect(result.groupId, 'g1');
    expect(result.member.slotNo, 9);
  });

  test('resetInviteCode parses the new Invite', () async {
    // Arrange
    adapter.body = {
      'data': {'invite_code': 'AB12CD34', 'invite_url': 'https://giliran.monai.my.id/j/AB12CD34'},
    };

    // Act
    final invite = await dataSource.resetInviteCode('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/invite-code/reset');
    expect(invite.inviteCode, 'AB12CD34');
  });

  test('addGuest leaves out a missing phone', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': memberJson('m5', isGuest: true, name: 'Bu Sri')};

    // Act
    await dataSource.addGuest('g1', const GuestRequestModel(name: 'Bu Sri'));

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/guests');
    expect(adapter.requests.single.data, {'name': 'Bu Sri'});
  });

  test('updateGuest sends a null phone to clear it', () async {
    // Arrange
    adapter.body = {'data': memberJson('m5', isGuest: true)};

    // Act
    await dataSource.updateGuest('g1', 'm5', {'phone': null});

    // Assert
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/groups/g1/members/m5');
    expect(adapter.requests.single.data, {'phone': null});
  });

  test('createClaimLink parses the ClaimLink', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': claimLinkJson};

    // Act
    final link = await dataSource.createClaimLink('g1', 'm5');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/members/m5/claim-link');
    expect(link.claimUrl, startsWith('https://giliran.monai.my.id/c/'));
    expect(link.expiresAt, DateTime.utc(2026, 11, 11, 3));
  });

  test('listLeaveRequests sends the status filter and parses each request', () async {
    // Arrange
    adapter.body = {
      'data': [leaveRequestJson('r1')],
    };

    // Act
    final requests = await dataSource.listLeaveRequests('g1', status: 'pending');

    // Assert
    expect(adapter.requests.single.queryParameters, {'status': 'pending'});
    expect(requests.single.member?.displayName, 'Dedi');
    expect(requests.single.reason, 'Pindah kota');
  });

  test('requestLeave without a reason sends an empty body', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': leaveRequestJson('r1')};

    // Act
    await dataSource.requestLeave('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/leave-requests');
    expect(adapter.requests.single.data, <String, Object?>{});
  });

  test('offerTransfer sends the target and parses the OwnershipTransfer', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': transferJson('t1')};

    // Act
    final transfer = await dataSource.offerTransfer('g1', 'm3');

    // Assert
    expect(adapter.requests.single.data, {'to_member_id': 'm3'});
    expect(transfer.fromUser?.name, 'Rina Ayu');
    expect(transfer.toMember?.id, 'm-3');
    expect(transfer.expiresAt, DateTime.utc(2026, 11, 9, 3));
  });

  test('saveFixedOrder sends every slot with its position', () async {
    // Arrange
    adapter.body = {
      'data': [memberJson('m1', fixedOrderPosition: 2), memberJson('m2', slotNo: 2, fixedOrderPosition: 1)],
    };

    // Act
    final members = await dataSource.saveFixedOrder(
      'g1',
      const FixedOrderRequestModel(
        order: [
          FixedOrderItemModel(slotId: 'slot-1', position: 2),
          FixedOrderItemModel(slotId: 'slot-2', position: 1),
        ],
      ),
    );

    // Assert
    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.data, {
      'order': [
        {'slot_id': 'slot-1', 'position': 2},
        {'slot_id': 'slot-2', 'position': 1},
      ],
    });
    expect(members.first.fixedOrderPosition, 2);
  });

  test('listObligations parses each Obligation', () async {
    // Arrange
    adapter.body = {
      'data': [obligationJson('m3', overdueCount: 1)],
    };

    // Act
    final obligations = await dataSource.listObligations('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/obligations');
    expect(obligations.single.remainingCount, 7);
    expect(obligations.single.remainingAmount, 1400000);
    expect(obligations.single.overdueCount, 1);
  });

  test('groupIdFromLocation reads the group segment', () {
    // Act
    final id = MemberRemoteDataSourceImpl.groupIdFromLocation('/api/v1/groups/g7/members/m1');

    // Assert
    expect(id, 'g7');
  });
}
