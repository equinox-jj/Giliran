import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/features/history/data/datasource/history_remote_data_source_impl.dart';

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
  late HistoryRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = HistoryRemoteDataSourceImpl(dio);
  });

  test('getActivity parses entries and the cursor meta', () async {
    // Arrange
    adapter.body = {
      'data': [
        activityJson(
          '42',
          action: 'payment.rejected',
          after: {'status': 'rejected', 'reject_reason': 'Nominal kurang'},
        ),
        activityJson('41', action: 'group.started', entityType: 'group', actor: null, subject: null),
      ],
      'meta': {'next_cursor': 'c2', 'has_more': true},
    };

    // Act
    final page = await dataSource.getActivity('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/activity');
    expect(adapter.requests.single.queryParameters, {'limit': 30});
    expect(page.items.map((e) => e.id), ['42', '41']);
    expect(page.items.first.actor?.name, 'Bu Rina');
    expect(page.items.first.subject?.slotNo, 2);
    expect(page.items.first.after?['reject_reason'], 'Nominal kurang');
    expect(page.items.last.actor, isNull);
    expect(page.nextCursor, 'c2');
    expect(page.hasMore, isTrue);
  });

  test('getActivity sends the cursor of the next page', () async {
    // Arrange
    adapter.body = {
      'data': <Object>[],
      'meta': {'next_cursor': null, 'has_more': false},
    };

    // Act
    final page = await dataSource.getActivity('g1', cursor: 'c2');

    // Assert
    expect(adapter.requests.single.queryParameters, {'limit': 30, 'cursor': 'c2'});
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });
}
