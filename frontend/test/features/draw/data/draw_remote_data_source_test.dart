import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/network/api_endpoints.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/draw_algorithm.dart';
import 'package:giliran/core/utils/enums/draw_status.dart';
import 'package:giliran/features/draw/data/datasource/draw_remote_data_source_impl.dart';
import 'package:giliran/features/draw/data/mappers/draw_mapper.dart';

import '../fixtures.dart';

/// Records each request with its JSON body and answers with [body].
class _RecordingAdapter() implements HttpClientAdapter {
  Object? body;
  int status = 200;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final sent = <int>[];
    await requestStream?.forEach(sent.addAll);
    bodies.add(utf8.decode(sent));
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
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
  late DrawRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = DrawRemoteDataSourceImpl(dio);
  });

  test('getDraw parses a committed draw with only the seed hash', () async {
    // Arrange
    adapter.body = {'data': committedDrawJson()};

    // Act
    final draw = (await dataSource.getDraw('g1', 'p1')).toEntity();

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/periods/p1/draw');
    expect(draw.status, DrawStatus.committed);
    expect(draw.seedHash, goldenSeedHash);
    expect(draw.seed, isNull);
    expect(draw.eligibleSlots, isEmpty);
    expect(draw.winner, isNull);
  });

  test('getDraw parses a drawn result with seed, slots and winner', () async {
    // Arrange
    adapter.body = {'data': drawnDrawJson()};

    // Act
    final draw = (await dataSource.getDraw('g1', 'p1')).toEntity();

    // Assert
    expect(draw.isDrawn, isTrue);
    expect(draw.algorithm, DrawAlgorithm.hmacSha256V1);
    expect(draw.seed, goldenSeed);
    expect(draw.eligibleSlots, hasLength(10));
    expect(draw.winner?.slotNo, 5);
    expect(draw.drawnBy?.name, 'Pak Budi');
    expect(draw.paidCountAtDraw, 8);
    expect(draw.verificationCode, '7H2K9QX4MP');
    expect(draw.drawnAt, DateTime.utc(2026, 10, 26, 12, 30));
  });

  test('runDraw sends the Idempotency-Key in extra and no confirm flag', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': drawnDrawJson()};

    // Act
    await dataSource.runDraw('g1', 'p1', key: const IdempotencyKey('key-1'));

    // Assert
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.extra[ApiEndpoints.kIdempotencyKey], 'key-1');
    expect(jsonDecode(adapter.bodies.single), isEmpty);
  });

  test('runDraw sends confirm_incomplete when confirmed', () async {
    // Arrange
    adapter
      ..status = 201
      ..body = {'data': drawnDrawJson()};

    // Act
    await dataSource.runDraw('g1', 'p1', confirmIncomplete: true, key: const IdempotencyKey('key-1'));

    // Assert
    expect(jsonDecode(adapter.bodies.single), {'confirm_incomplete': true});
  });

  test('payments_incomplete keeps the paid and total counts', () async {
    // Arrange
    adapter
      ..status = 409
      ..body = {
        'type': 'https://giliran.monai.my.id/problems/payments-incomplete',
        'title': 'Payments incomplete',
        'status': 409,
        'code': 'payments_incomplete',
        'paid_count': 8,
        'total_count': 10,
      };

    // Act
    final call = dataSource.runDraw('g1', 'p1', key: const IdempotencyKey('key-1'));

    // Assert
    await expectLater(
      call,
      throwsA(
        isA<ConflictException>()
            .having((e) => e.problem?.paidCount, 'paidCount', 8)
            .having((e) => e.problem?.totalCount, 'totalCount', 10),
      ),
    );
  });
}
