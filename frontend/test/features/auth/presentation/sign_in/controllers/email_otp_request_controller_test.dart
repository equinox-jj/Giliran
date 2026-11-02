import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/presentation/sign_in/controllers/email_otp_request_controller.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  test('holds the sent challenge', () async {
    // Arrange
    final container = authTestContainer(repository);
    container.listen(emailOtpRequestControllerProvider, (_, _) {});

    // Act
    final sent = await container
        .read(emailOtpRequestControllerProvider.notifier)
        .request(purpose: OtpPurpose.signIn, email: 'ana@example.com');

    // Assert
    expect(sent, isTrue);
    expect(
      container.read(emailOtpRequestControllerProvider).value,
      const EmailOtpChallenge(id: 'otp-1'),
    );
  });

  test('holds the failure as an error', () async {
    // Arrange
    repository.challengeResult = const Left(Failure.tooManyRequests());
    final container = authTestContainer(repository);
    container.listen(emailOtpRequestControllerProvider, (_, _) {});

    // Act
    final sent = await container
        .read(emailOtpRequestControllerProvider.notifier)
        .request(purpose: OtpPurpose.signIn, email: 'ana@example.com');

    // Assert
    expect(sent, isFalse);
    expect(
      container.read(emailOtpRequestControllerProvider).error,
      isA<TooManyRequestsFailure>(),
    );
  });
}
