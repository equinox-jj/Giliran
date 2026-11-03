import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/group/data/datasource/group_remote_data_source_impl.dart';
import 'package:giliran/features/group/data/datasource/model/group_request_model.dart';

import '../../fixtures.dart';

/// Records each request and answers with [body].
class _RecordingAdapter() implements HttpClientAdapter {
  Object? body;
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
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late GroupRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter()..body = {'data': groupJson};
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = GroupRemoteDataSourceImpl(dio);
  });

  test('getGroup parses the GroupEnvelope', () async {
    // Act
    final group = await dataSource.getGroup('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1');
    expect(group.name, 'Arisan RT 05');
    expect(group.potAmount, 2000000);
    expect(group.organizer?.name, 'Rina Ayu');
    expect(group.invite?.inviteCode, 'K7P2QX9M');
    expect(group.paymentInfo?.accountNumber, '1234567890');
    expect(group.createdAt, DateTime.utc(2026, 11, 1, 3));
  });

  test('listMyGroups sends the status filter and parses every summary', () async {
    // Arrange
    adapter.body = {
      'data': [summaryJson('g1'), summaryJson('g2', name: 'Arisan Kantor')],
    };

    // Act
    final groups = await dataSource.listMyGroups('finished');

    // Assert
    expect(adapter.requests.single.path, '/me/groups');
    expect(adapter.requests.single.queryParameters, {'status': 'finished'});
    expect(groups.map((g) => g.name), ['Arisan RT 05', 'Arisan Kantor']);
    expect(groups.first.myPaymentStatus, 'unpaid');
  });

  test('updateGroup sends only the changed fields', () async {
    // Arrange
    const body = UpdateGroupRequestModel(name: 'Arisan Baru');

    // Act
    await dataSource.updateGroup('g1', body);

    // Assert
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.data, {'name': 'Arisan Baru'});
  });

  test('closeGroup posts to the close path', () async {
    // Act
    await dataSource.closeGroup('g1');

    // Assert
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/groups/g1/close');
  });
}
