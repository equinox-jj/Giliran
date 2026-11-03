import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/presentation/change_email/page/change_email_page.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late int doneCalls;

  final challenge = EmailOtpChallenge(
    id: 'otp-7',
    purpose: OtpPurpose.changeEmail,
    emailMasked: 'ba•••••@example.com',
    resendAvailableAt: DateTime(2020),
  );

  setUp(() {
    repository = FakeAuthRepository()
      ..userResult = Right(ProfileData(name: 'Ana', email: 'ana@example.com', pinSet: true))
      ..challengeResult = Right(challenge)
      ..pendingResult = Right(PendingOtp(email: 'baru@example.com', challenge: challenge));
    container = authTestContainer(repository);
    doneCalls = 0;
  });

  Future<void> pumpChangeEmail(WidgetTester tester) async {
    await container.read(authSessionControllerProvider.future);
    container.read(authSessionControllerProvider.notifier).unlock();
    await tester.pumpPage(
      ChangeEmailPage(onDone: () => doneCalls++, onForgotPin: () {}),
      container: container,
      size: const Size(390, 1200),
    );
    await tester.pump();
  }

  Future<void> submitEmail(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextField), email);
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> toCodeStep(WidgetTester tester) async {
    await submitEmail(tester, 'baru@example.com');
    await tester.enterPin('246802');
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the current email above the new address field', (tester) async {
    // Arrange
    // (the account email is ana@example.com)

    // Act
    await pumpChangeEmail(tester);

    // Assert
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Email baru'), findsOneWidget);
  });

  testWidgets('the current address stays on step 1 with the reason', (tester) async {
    // Arrange
    await pumpChangeEmail(tester);

    // Act
    await submitEmail(tester, 'ANA@example.com');

    // Assert
    expect(find.text('Ini email kamu yang sekarang.'), findsOneWidget);
    expect(find.text('Ubah email · 1 dari 3'), findsOneWidget);
  });

  testWidgets('a new address asks for the PIN', (tester) async {
    // Arrange
    await pumpChangeEmail(tester);

    // Act
    await submitEmail(tester, 'baru@example.com');

    // Assert
    expect(find.text('Masukkan PIN kamu'), findsOneWidget);
    expect(find.text('Ubah email · 2 dari 3'), findsOneWidget);
  });

  testWidgets('a taken address returns to step 1 with the reason', (tester) async {
    // Arrange
    repository.challengeResult = const Left(
      Failure.conflict(code: ApiErrorCode.emailAlreadyRegistered),
    );
    await pumpChangeEmail(tester);
    await submitEmail(tester, 'baru@example.com');

    // Act
    await tester.enterPin('246802');
    await tester.pump();
    await tester.pump();

    // Assert
    expect(find.text('Email ini sudah punya akun Giliran.'), findsOneWidget);
    expect(find.text('Ubah email · 1 dari 3'), findsOneWidget);
  });

  testWidgets('a wrong PIN shows the attempts left', (tester) async {
    // Arrange
    repository.challengeResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinInvalid,
        status: 401,
        extensions: {'attempts_remaining': 4},
      ),
    );
    await pumpChangeEmail(tester);
    await submitEmail(tester, 'baru@example.com');

    // Act
    await tester.enterPin('000000');
    await tester.pump();
    await tester.pump();

    // Assert
    expect(find.text('PIN salah. Sisa 4 percobaan.'), findsOneWidget);
  });

  testWidgets('the PIN sends the code to the new address and opens the card', (tester) async {
    // Arrange
    await pumpChangeEmail(tester);

    // Act
    await toCodeStep(tester);

    // Assert
    expect(
      repository.requestArgs,
      (OtpPurpose.changeEmail, 'baru@example.com', '246802'),
    );
    expect(find.byType(EmailCodeCard), findsOneWidget);
    expect(find.text('Buka aplikasi email'), findsOneWidget);
  });

  testWidgets('a verified code shows the toast and closes', (tester) async {
    // Arrange
    repository.verifyResult = Right(
      EmailOtpResult(
        purpose: OtpPurpose.changeEmail,
        user: ProfileData(name: 'Ana', email: 'baru@example.com', pinSet: true),
      ),
    );
    await pumpChangeEmail(tester);
    await toCodeStep(tester);

    // Act
    await tester.enterText(find.byType(TextField), '482913');
    await tester.pump();
    await tester.pump();

    // Assert
    expect(repository.calls, contains('verifyEmailOtp'));
    expect(find.text('Email diganti. Perangkat lain sudah dikeluarkan.'), findsOneWidget);
    expect(doneCalls, 1);
  });

  testWidgets('close on step 1 closes the flow', (tester) async {
    // Arrange
    await pumpChangeEmail(tester);

    // Act
    await tester.tap(find.bySemanticsLabel('Tutup'));
    await tester.pump();

    // Assert
    expect(doneCalls, 1);
  });
}
