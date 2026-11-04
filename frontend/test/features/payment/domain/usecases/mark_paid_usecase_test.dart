import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/features/payment/domain/usecases/mark_paid_usecase.dart';

import '../../../../helpers/fake_payment_repository.dart';

void main() {
  late FakePaymentRepository repository;
  late MarkPaidUseCase useCase;

  setUp(() {
    repository = FakePaymentRepository();
    useCase = MarkPaidUseCase(repository);
  });

  test('rejects a note over 500 characters locally', () async {
    // Act
    final result = await useCase((
      groupId: 'g1',
      paymentId: 'pay1',
      method: PaymentMethod.cash,
      note: 'x' * 501,
      key: const IdempotencyKey('k'),
    ));

    // Assert
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(repository.calls, isEmpty);
  });

  test('sends a blank note as none', () async {
    // Act
    await useCase((
      groupId: 'g1',
      paymentId: 'pay1',
      method: PaymentMethod.other,
      note: '   ',
      key: const IdempotencyKey('k'),
    ));

    // Assert
    expect(repository.calls, ['markPaid']);
    expect(repository.lastMethod, PaymentMethod.other);
    expect(repository.lastNote, isNull);
  });
}
