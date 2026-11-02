import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/biometric_kind.dart';
import 'package:giliran/features/auth/domain/entities/biometric_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/biometric_controller.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  test('turning it on saves the choice and stops the offer', () async {
    // Arrange
    final repository = FakeAuthRepository();
    final container = authTestContainer(repository);
    container.listen(biometricControllerProvider, (_, _) {});
    final before = await container.read(biometricControllerProvider.future);

    // Act
    final failure = await container.read(biometricControllerProvider.notifier).setEnabled(true);

    // Assert
    expect(failure, isNull);
    expect(before.shouldOffer, isTrue);
    expect(
      container.read(biometricControllerProvider).value,
      const BiometricStatus(
        kind: BiometricKind.fingerprint,
        enabled: true,
        shouldOffer: false,
      ),
    );
  });
}
