import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/draw/domain/usecases/run_draw_usecase.dart';

import '../../../../helpers/fake_draw_repository.dart';
import '../../../../helpers/fake_payment_repository.dart';
import '../../fixtures.dart';

void main() {
  late FakeDrawRepository draws;
  late FakePaymentRepository payments;
  late RunDrawUseCase useCase;

  setUp(() {
    draws = FakeDrawRepository();
    payments = FakePaymentRepository();
    useCase = RunDrawUseCase(draws, payments);
  });

  RunDrawParams params({bool confirm = false, String key = 'k1'}) =>
      (groupId: 'g1', periodId: 'p1', confirmIncomplete: confirm, key: IdempotencyKey(key));

  test('runDraw retry reuses the idempotency key', () async {
    // Arrange
    draws
      ..runResults.add(const Left(Failure.timeout()))
      ..runResult = Right(drawnDraw);

    // Act
    final first = await useCase(params());
    final retry = await useCase(params());

    // Assert
    expect(first.getLeft().toNullable(), isA<TimeoutFailure>());
    expect(retry.isRight(), isTrue);
    expect(draws.keys, ['k1', 'k1']);
  });

  test('payments_incomplete then a confirmed resend with the same key', () async {
    // Arrange
    draws
      ..runResults.add(
        const Left(
          Failure.conflict(code: ApiErrorCode.paymentsIncomplete, extensions: {'paid_count': 8, 'total_count': 10}),
        ),
      )
      ..runResult = Right(drawnDraw);

    // Act
    final first = await useCase(params());
    final confirmed = await useCase(params(confirm: true));

    // Assert
    final failure = first.getLeft().toNullable();
    expect(failure?.apiCode, ApiErrorCode.paymentsIncomplete);
    expect((failure! as ConflictFailure).extensions['paid_count'], 8);
    expect(confirmed.getRight().toNullable()?.winner?.slotNo, 5);
    expect(draws.confirms, [false, true]);
    expect(draws.keys, ['k1', 'k1']);
  });

  for (final code in [ApiErrorCode.drawAlreadyDone, ApiErrorCode.drawTooEarly]) {
    test('${code.apiValue} maps through without a refresh', () async {
      // Arrange
      draws.runResult = Left(Failure.conflict(code: code));

      // Act
      final result = await useCase(params());

      // Assert
      expect(result.getLeft().toNullable()?.apiCode, code);
      expect(payments.calls, isNot(contains('refreshPeriods')));
    });
  }

  test('a successful draw refreshes the cached periods', () async {
    // Arrange
    draws.runResult = Right(drawnDraw);

    // Act
    await useCase(params());

    // Assert
    expect(payments.calls, contains('refreshPeriods'));
  });
}
