import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/payment/domain/usecases/upload_proof_usecase.dart';

import '../../../../helpers/fake_payment_repository.dart';

void main() {
  late FakePaymentRepository repository;

  UploadProofParams params() =>
      (groupId: 'g1', paymentId: 'pay1', path: '/tmp/proof.jpg', key: const IdempotencyKey('k'), onProgress: null);

  setUp(() => repository = FakePaymentRepository());

  test('a file over 5 MB fails with file_too_large before any upload', () async {
    // Arrange
    final useCase = UploadProofUseCase(repository, (_) async => 6 * 1024 * 1024);

    // Act
    final result = await useCase(params());

    // Assert
    expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.fileTooLarge);
    expect(repository.calls, isEmpty);
  });

  test('a file of 5 MB or less is uploaded', () async {
    // Arrange
    final useCase = UploadProofUseCase(repository, (_) async => UploadProofUseCase.maxBytes);

    // Act
    await useCase(params());

    // Assert
    expect(repository.calls, ['uploadProof']);
  });
}
