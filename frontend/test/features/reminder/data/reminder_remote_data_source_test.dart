import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/network/api_endpoints.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/reminder_skip_reason.dart';
import 'package:giliran/features/reminder/data/datasource/reminder_remote_data_source_impl.dart';
import 'package:giliran/features/reminder/data/mappers/reminder_mapper.dart';

/// Records each request with its JSON body and answers with [body].
class _RecordingAdapter() implements HttpClientAdapter {
  Object? body;
  int status = 200;
  Map<String, List<String>> headers = {};
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
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _member(String id, String name, int slot, {bool guest = false}) => {
  'id': id,
  'display_name': name,
  'is_guest': guest,
  'slot_no': slot,
  'avatar_url': null,
};

void main() {
  late _RecordingAdapter adapter;
  late ReminderRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    dataSource = ReminderRemoteDataSourceImpl(dio);
  });

  test('getRecap parses counts, dates, unpaid members and payment info', () async {
    // Arrange
    adapter.body = {
      'data': {
        'group_name': 'Arisan RT 05',
        'period_no': 4,
        'total_periods': 10,
        'due_date': '2026-10-25',
        'draw_date': '2026-10-26',
        'amount': 200000,
        'paid_count': 8,
        'total_count': 10,
        'collected_amount': 1600000,
        'expected_amount': 2000000,
        'unpaid': [
          {'member': _member('m4', 'Pak Dedi', 4), 'whatsapp_phone': '+6281234567890'},
          {'member': _member('m7', 'Bu Ani', 7, guest: true), 'whatsapp_phone': null},
        ],
        'last_winner': _member('m3', 'Bu Sri', 3),
        'payment_info': {
          'bank_name': 'BCA',
          'account_number': '1234567890',
          'account_holder': 'Rina',
          'qris_image_url': null,
          'qris_merchant_name': null,
        },
      },
    };

    // Act
    final recap = (await dataSource.getRecap('g1', 'p1')).toEntity();

    // Assert
    expect(adapter.requests.single.path, '/groups/g1/periods/p1/recap');
    expect(recap.periodNo, 4);
    expect(recap.dueDate, DateTime.utc(2026, 10, 25));
    expect(recap.drawDate, DateTime.utc(2026, 10, 26));
    expect(recap.collectedAmount, 1600000);
    expect(recap.unpaid, hasLength(2));
    expect(recap.unpaid.first.whatsappPhone, '+6281234567890');
    expect(recap.unpaid.last.member?.isGuest, isTrue);
    expect(recap.lastWinner?.displayName, 'Bu Sri');
    expect(recap.paymentInfo?.hasBankAccount, isTrue);
    expect(recap.allPaid, isFalse);
  });

  test('sendReminders posts member_ids with the Idempotency-Key in extra', () async {
    // Arrange
    adapter.body = {
      'data': {
        'sent_count': 1,
        'skipped': [
          {'member': _member('m7', 'Bu Ani', 7, guest: true), 'reason': 'guest', 'whatsapp_phone': '+628111'},
          {'member': _member('m9', 'Pak Joko', 9), 'reason': 'brand_new_reason', 'whatsapp_phone': null},
        ],
      },
    };

    // Act
    final result = (await dataSource.sendReminders(
      'g1',
      'p1',
      memberIds: ['m4', 'm7'],
      key: const IdempotencyKey('key-1'),
    )).toEntity();

    // Assert
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/groups/g1/periods/p1/reminders');
    expect(request.extra[ApiEndpoints.kIdempotencyKey], 'key-1');
    expect(jsonDecode(adapter.bodies.single), {
      'member_ids': ['m4', 'm7'],
    });
    expect(result.sentCount, 1);
    expect(result.skipped.first.reason, ReminderSkipReason.guest);
    expect(result.skipped.last.reason, isNull);
  });

  test('rate_limit_exceeded keeps the Retry-After wait', () async {
    // Arrange
    adapter
      ..status = 429
      ..headers = {
        'retry-after': ['30'],
      }
      ..body = {
        'type': 'about:blank',
        'title': 'Too many requests',
        'status': 429,
        'code': 'rate_limit_exceeded',
      };

    // Act
    final call = dataSource.sendReminders('g1', 'p1', memberIds: ['m4'], key: const IdempotencyKey('key-1'));

    // Assert
    await expectLater(
      call,
      throwsA(isA<TooManyRequestsException>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 30))),
    );
  });
}
