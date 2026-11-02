import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/presentation/forgot_pin/page/forgot_pin_page.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late int back;

  final challenge = EmailOtpChallenge(
    id: 'otp-9',
    purpose: OtpPurpose.resetPin,
    emailMasked: 'ri•••••@gmail.com',
    resendAvailableAt: DateTime(2020),
  );

  setUp(() {
    repository = FakeAuthRepository()
      ..hasSessionResult = const Right(false)
      ..challengeResult = Right(challenge)
      ..pendingResult = Right(PendingOtp(email: 'rina@gmail.com', challenge: challenge));
    container = authTestContainer(repository);
    back = 0;
  });

  Future<void> pumpForgot(WidgetTester tester, {String? email = 'rina@gmail.com'}) async {
    await tester.pumpPage(
      ForgotPinPage(email: email, onBack: () => back++),
      container: container,
      size: const Size(390, 1200),
    );
    await tester.pump();
  }

  Future<void> sendCode(WidgetTester tester) async {
    await tester.tap(find.text('Kirim kode'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> typeCode(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '482913');
    await tester.pump();
  }

  test('maskEmail keeps two letters and the domain', () {
    // Arrange
    const email = 'rina@gmail.com';

    // Act
    final masked = maskEmail(email);

    // Assert
    expect(masked, 'ri•••••@gmail.com');
  });

  testWidgets('explains where the code goes', (tester) async {
    // Arrange
    // (the account email)

    // Act
    await pumpForgot(tester);

    // Assert
    expect(
      find.text('Kami kirim kode ke ri•••••@gmail.com untuk memastikan ini kamu.'),
      findsOneWidget,
    );
  });

  testWidgets('without an email the code cannot be sent', (tester) async {
    // Arrange
    await pumpForgot(tester, email: null);

    // Act
    final button = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Kirim kode'));

    // Assert
    expect(button.onPressed, isNull);
  });

  testWidgets('sends a reset_pin code and shows the code card', (tester) async {
    // Arrange
    await pumpForgot(tester);

    // Act
    await sendCode(tester);

    // Assert
    expect(repository.savedPending?.challenge?.purpose, OtpPurpose.resetPin);
    expect(find.byType(EmailCodeCard), findsOneWidget);
  });

  testWidgets('verifies the code with the new PIN typed twice', (tester) async {
    // Arrange
    repository.verifyResult = Right(
      EmailOtpResult(
        purpose: OtpPurpose.resetPin,
        auth: AuthResult(user: ProfileData(name: 'Rina', pinSet: true)),
      ),
    );
    await pumpForgot(tester);
    await sendCode(tester);
    await typeCode(tester);
    final askedNewPin = find.text('Buat PIN baru').evaluate().isNotEmpty;
    await tester.enterPin('135790');

    // Act
    await tester.enterPin('135790');
    await tester.pump();
    await tester.pump();

    // Assert
    expect(askedNewPin, isTrue);
    expect(repository.calls, contains('verifyEmailOtp'));
    expect(find.text('PIN baru tersimpan. Perangkat lain sudah dikeluarkan.'), findsOneWidget);
  });

  testWidgets('a wrong code goes back to the code step', (tester) async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.otpInvalid,
        status: 422,
        extensions: {'attempts_remaining': 3},
      ),
    );
    await pumpForgot(tester);
    await sendCode(tester);
    await typeCode(tester);
    await tester.enterPin('135790');

    // Act
    await tester.enterPin('135790');
    await tester.pump();

    // Assert
    expect(find.byType(EmailCodeCard), findsOneWidget);
    expect(find.text('Kode salah. Sisa 3 kali coba.'), findsOneWidget);
  });

  testWidgets('back on the first step leaves', (tester) async {
    // Arrange
    await pumpForgot(tester);

    // Act
    await tester.tap(find.bySemanticsLabel('Kembali'));

    // Assert
    expect(back, 1);
  });
}
