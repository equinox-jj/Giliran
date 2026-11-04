import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/features/payment/domain/usecases/reject_payment_usecase.dart';

import '../../../../helpers/fake_payment_repository.dart';

void main() {
  late FakePaymentRepository repository;
  late RejectPaymentUseCase useCase;

  setUp(() {
    repository = FakePaymentRepository();
    useCase = RejectPaymentUseCase(repository);
  });

  for (final reason in ['ab', 'x' * 501, '   a  ']) {
    test('rejects a ${reason.trim().length}-character reason locally', () async {
      // Act
      final result = await useCase((groupId: 'g1', paymentId: 'pay1', reason: reason, key: const IdempotencyKey('k')));

      // Assert
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(repository.calls, isEmpty);
    });
  }

  test('sends a trimmed reason of 3 to 500 characters', () async {
    // Act
    await useCase((groupId: 'g1', paymentId: 'pay1', reason: '  Nominal kurang ', key: const IdempotencyKey('k')));

    // Assert
    expect(repository.calls, ['rejectPayment']);
    expect(repository.lastReason, 'Nominal kurang');
  });
}
