import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/network/api_endpoints.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/features/payment/data/datasource/payment_remote_data_source_impl.dart';

import '../../fixtures.dart';

/// Records each request and answers with [body].
class _RecordingAdapter() implements HttpClientAdapter {
  Object? body;
  int status = 200;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
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
  late PaymentRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = PaymentRemoteDataSourceImpl(dio);
  });

  test('getPaymentBoard parses the payments and meta.summary', () async {
    // Arrange
    adapter.body = {
      'data': [
        paymentJson('pay1', status: 'paid', method: 'cash'),
        paymentJson('pay2', slotNo: 2, status: 'pending_review'),
      ],
      'meta': {'summary': summaryJson},
    };

    // Act
    final board = await dataSource.getPaymentBoard('g1', 'p1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/periods/p1/payments');
    expect(board.payments.map((p) => p.id), ['pay1', 'pay2']);
    expect(board.payments.first.method, 'cash');
    expect(board.payments.last.currentProof?.id, 'pr1');
    expect(board.summary?.paidCount, 8);
    expect(board.summary?.expectedAmount, 2000000);
  });

  test('listPeriods parses each Period with its summary', () async {
    // Arrange
    adapter.body = {
      'data': [
        periodJson('p1', status: 'closed', winner: memberRefJson('m3', slotNo: 3)),
        periodJson('p2', periodNo: 2),
      ],
    };

    // Act
    final periods = await dataSource.listPeriods('g1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/periods');
    expect(periods.first.winner?.slotNo, 3);
    expect(periods.last.dueDate, '2026-11-25');
    expect(periods.last.paymentSummary?.totalCount, 10);
  });

  test('approvePayment sends the Idempotency-Key in extra', () async {
    // Arrange
    adapter.body = {'data': paymentJson('pay1', status: 'paid')};

    // Act
    await dataSource.approvePayment('g1', 'pay1', key: const IdempotencyKey('key-1'));

    // Assert
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/groups/g1/payments/pay1/approve');
    expect(request.extra[ApiEndpoints.kIdempotencyKey], 'key-1');
  });

  test('rejectPayment sends the reason', () async {
    // Arrange
    adapter.body = {'data': paymentJson('pay1', status: 'rejected', rejectReason: 'Nominal kurang')};

    // Act
    final payment = await dataSource.rejectPayment(
      'g1',
      'pay1',
      reason: 'Nominal kurang',
      key: const IdempotencyKey('key-2'),
    );

    // Assert
    expect(adapter.requests.single.data, {'reason': 'Nominal kurang'});
    expect(payment.rejectReason, 'Nominal kurang');
  });

  test('markPaid sends the method and leaves out a missing note', () async {
    // Arrange
    adapter.body = {'data': paymentJson('pay1', status: 'paid', method: 'cash')};

    // Act
    await dataSource.markPaid('g1', 'pay1', method: 'cash', key: const IdempotencyKey('key-3'));

    // Assert
    final request = adapter.requests.single;
    expect(request.path, '/groups/g1/payments/pay1/mark-paid');
    expect(request.data, {'method': 'cash'});
    expect(request.extra[ApiEndpoints.kIdempotencyKey], 'key-3');
  });

  test('markPaid sends paid_at as UTC ISO 8601', () async {
    // Arrange
    adapter.body = {'data': paymentJson('pay1', status: 'paid', method: 'cash')};

    // Act
    await dataSource.markPaid(
      'g1',
      'pay1',
      method: 'cash',
      paidAt: DateTime.utc(2026, 11, 1, 5, 30),
      key: const IdempotencyKey('key-5'),
    );

    // Assert
    expect(adapter.requests.single.data, {'method': 'cash', 'paid_at': '2026-11-01T05:30:00.000Z'});
  });

  test('uploadProof posts the image as multipart with an image content type', () async {
    // Arrange
    final dir = await Directory.systemTemp.createTemp('proof');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/proof.png')..writeAsBytesSync([1, 2, 3]);
    adapter.body = {'data': paymentJson('pay1', status: 'pending_review')};

    // Act
    await dataSource.uploadProof('g1', 'pay1', file.path, key: const IdempotencyKey('key-4'));

    // Assert
    final request = adapter.requests.single;
    expect(request.path, '/groups/g1/payments/pay1/proofs');
    final form = request.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.contentType?.mimeType, 'image/png');
    expect(request.extra[ApiEndpoints.kIdempotencyKey], 'key-4');
  });

  test('getPayout parses the Payout', () async {
    // Arrange
    adapter.body = {'data': payoutJson('p1')};

    // Act
    final payout = await dataSource.getPayout('g1', 'p1');

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/periods/p1/payout');
    expect(payout.amount, 2000000);
    expect(payout.recordedBy?.name, 'Bu Sari');
  });
}
