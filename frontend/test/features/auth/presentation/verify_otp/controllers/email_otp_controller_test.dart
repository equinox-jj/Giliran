import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/auth/presentation/verify_otp/controllers/email_otp_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() async {
    repository = FakeAuthRepository()
      ..hasSessionResult = const Right(false)
      ..pendingResult = Right(
        PendingOtp(
          email: 'ana@example.com',
          challenge: EmailOtpChallenge(
            id: 'otp-1',
            purpose: OtpPurpose.signIn,
            attemptsRemaining: 5,
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ),
      );
    container = authTestContainer(repository);
    // Keep the auto-dispose controller alive across awaits.
    container.listen(emailOtpControllerProvider, (_, _) {});
    await container.read(emailOtpControllerProvider.future);
  });

  EmailOtpState state() => container.read(emailOtpControllerProvider).requireValue;

  EmailOtpController controller() => container.read(emailOtpControllerProvider.notifier);

  test('loads the open code request', () {
    // Arrange
    // (setUp loads the pending code)

    // Act
    final pending = state().pending;

    // Assert
    expect(pending?.email, 'ana@example.com');
    expect(pending?.challenge?.id, 'otp-1');
  });

  test('turns on the PIN step after pin_required', () async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinRequired, status: 422),
    );

    // Act
    await controller().verify('123456');

    // Assert
    expect(state().pinRequired, isTrue);
    expect(state().submitting, isFalse);
  });

  test('shows the attempts left after a wrong code', () async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.otpInvalid,
        status: 422,
        extensions: {'attempts_remaining': 3},
      ),
    );

    // Act
    await controller().verify('000000');

    // Assert
    expect(state().pending?.challenge?.attemptsRemaining, 3);
    expect(state().failure?.apiCode, ApiErrorCode.otpInvalid);
  });

  test('a verify with the PIN unlocks the new session', () async {
    // Arrange
    final user = ProfileData(name: 'Ana', pinSet: true);
    repository.verifyResult = Right(
      EmailOtpResult(
        purpose: OtpPurpose.signIn,
        auth: AuthResult(user: user, pinSet: true),
      ),
    );
    repository.hasSessionResult = const Right(true);
    repository.userResult = Right(user);

    // Act
    await controller().verify('123456', pin: '135790');

    // Assert
    expect(state().result?.auth?.user, user);
    expect(
      container.read(authSessionControllerProvider).value,
      AuthStatus.unlocked(user: user),
    );
  });

  test('resend replaces the challenge', () async {
    // Arrange
    final sent = EmailOtpChallenge(id: 'otp-1', attemptsRemaining: 5, codeLength: 6);
    repository.challengeResult = Right(sent);

    // Act
    await controller().resend();

    // Assert
    expect(state().pending?.challenge, sent);
    expect(state().resending, isFalse);
  });

  test('a new code after otp_expired clears the failure', () async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(code: ApiErrorCode.otpExpired, status: 422),
    );
    await controller().verify('123456');
    repository.challengeResult = Right(
      EmailOtpChallenge(id: 'otp-1', attemptsRemaining: 5, codeLength: 6),
    );

    // Act
    await controller().resend();

    // Assert
    expect(state().failure, isNull);
  });
}
