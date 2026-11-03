import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/group/domain/entities/group_input.dart';
import 'package:giliran/features/group/domain/usecases/update_payment_info_usecase.dart';

import '../../../../helpers/fake_group_repository.dart';

void main() {
  late FakeGroupRepository repository;
  late UpdatePaymentInfoUseCase useCase;

  setUp(() {
    repository = FakeGroupRepository();
    useCase = UpdatePaymentInfoUseCase(repository);
  });

  test('sends the grouped account number as digits only', () async {
    // Arrange
    const input = PaymentInfoInput(bankName: ' BCA ', accountNumber: '1234 5678 90', accountHolder: 'Rina Ayu');

    // Act
    await useCase((groupId: 'g1', input: input));

    // Assert
    expect(repository.lastPaymentInfo?.accountNumber, '1234567890');
    expect(repository.lastPaymentInfo?.bankName, 'BCA');
  });

  test('rejects an account number shorter than 6 digits', () async {
    // Arrange
    const input = PaymentInfoInput(bankName: 'BCA', accountNumber: '12345', accountHolder: 'Rina');

    // Act
    final result = await useCase((groupId: 'g1', input: input));

    // Assert
    final failure = result.getLeft().toNullable();
    expect(failure, isA<ValidationFailure>());
    expect(failure?.fieldMessage('account_number'), '');
    expect(repository.calls, isEmpty);
  });
}
