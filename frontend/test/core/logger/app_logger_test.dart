import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/errors/errors.dart';
import 'package:giliran/core/logger/logger.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:logging/logging.dart';

void main() {
  late List<LogRecord> records;
  late StreamSubscription<LogRecord> subscription;

  setUpAll(AppLogger.init);

  setUp(() {
    records = [];
    subscription = Logger.root.onRecord.listen(records.add);
  });

  tearDown(() => subscription.cancel());

  test('logs debug records to tagged loggers', () {
    AppLogger.d('hello');
    AppLogger.w('careful', tag: 'auth');

    expect(records.map((r) => (r.level, r.loggerName)), [
      (Level.FINE, 'Giliran'),
      (Level.WARNING, 'Giliran.auth'),
    ]);
  });

  test('redacts the message and data', () {
    AppLogger.i(
      'sign in sari@example.com',
      data: {'email': 'sari@example.com', 'device': 'Pixel 8'},
    );

    final message = records.single.message;
    expect(message, startsWith('sign in «email»'));
    expect(message, contains('"email": "$redactedValue"'));
    expect(message, contains('"device": "Pixel 8"'));
    expect(message, isNot(contains('sari@')));
  });

  test('falls back to toString for data JSON cannot encode', () {
    AppLogger.d('x', data: Duration.zero);
    expect(records.single.message, 'x\n0:00:00.000000');
  });

  test('describes a ServerFailure without detail or extensions', () {
    AppLogger.e(
      'failed',
      error: const ServerFailure(
        code: ApiErrorCode.unknown,
        status: 500,
        requestId: 'req-1',
        detail: 'pin 482913 for sari@example.com',
        extensions: {'pin': '482913'},
      ),
    );

    expect(
      records.single.error,
      'ServerFailure(code: unknown, status: 500, requestId: req-1)',
    );
  });

  test('scrubs other errors', () {
    AppLogger.e('failed', error: Exception('no user sari@example.com'));
    expect(records.single.error, 'Exception: no user «email»');
  });

  test('guard logs unexpected failures only', () async {
    await expectLater(
      guard<void>(() async => throw const FormatException('bad body')),
      throwsA(isA<UnexpectedFailure>()),
    );
    await expectLater(
      guard<void>(() async => throw const NetworkException()),
      throwsA(isA<NetworkFailure>()),
    );

    expect(records, hasLength(1));
    expect(records.single.loggerName, 'Giliran.data');
    expect(records.single.error, contains('bad body'));
    expect(records.single.stackTrace, isNotNull);
  });
}
