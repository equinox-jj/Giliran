import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/presentation/verify_otp/page/verify_otp_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;
  late List<String?> changedTo;
  late List<String?> forgotFor;

  final pending = PendingOtp(
    email: 'rina@gmail.com',
    challenge: EmailOtpChallenge(
      id: 'otp-1',
      purpose: OtpPurpose.signIn,
      emailMasked: 'ri•••••@gmail.com',
      // In the past, so no resend countdown ticks.
      resendAvailableAt: DateTime(2020),
    ),
  );

  setUp(() {
    repository = FakeAuthRepository()
      ..hasSessionResult = const Right(false)
      ..pendingResult = Right(pending);
    container = authTestContainer(repository);
    changedTo = [];
    forgotFor = [];
  });

  Future<void> pumpCode(WidgetTester tester) async {
    await tester.pumpPage(
      VerifyOtpPage(onChangeEmail: changedTo.add, onForgotPin: forgotFor.add),
      container: container,
      size: const Size(390, 1400),
    );
    await tester.pump();
  }

  Future<void> typeCode(WidgetTester tester, [String code = '482913']) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the card for the open request', (tester) async {
    // Arrange
    // (an open sign-in request)

    // Act
    await pumpCode(tester);

    // Assert
    expect(find.text('Cek email kamu'), findsOneWidget);
    expect(find.text('ri•••••@gmail.com'), findsOneWidget);
    expect(find.byType(OtpInput), findsOneWidget);
  });

  testWidgets('goes back to sign-in when there is no open request', (tester) async {
    // Arrange
    repository.pendingResult = const Right(null);

    // Act
    await pumpCode(tester);

    // Assert
    expect(changedTo, [null]);
  });

  testWidgets('Ubah goes back with the typed address', (tester) async {
    // Arrange
    await pumpCode(tester);

    // Act
    await tester.tap(find.text('Ubah'));

    // Assert
    expect(changedTo, ['rina@gmail.com']);
  });

  testWidgets('a wrong code shows the attempts left', (tester) async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.otpInvalid,
        status: 422,
        extensions: {'attempts_remaining': 2},
      ),
    );
    await pumpCode(tester);

    // Act
    await typeCode(tester);

    // Assert
    expect(find.text('Kode salah. Sisa 2 kali coba.'), findsOneWidget);
  });

  testWidgets('an expired code offers a new one', (tester) async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(code: ApiErrorCode.otpExpired, status: 410),
    );
    await pumpCode(tester);

    // Act
    await typeCode(tester);

    // Assert
    expect(find.text('Kirim kode baru'), findsOneWidget);
  });

  testWidgets('pin_required adds the PIN step and verifies with the PIN', (tester) async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinRequired, status: 422),
    );
    await pumpCode(tester);
    await typeCode(tester);
    final pinShown = find.byType(PinPad).evaluate().isNotEmpty;
    repository.verifyResult = const Right(EmailOtpResult(purpose: OtpPurpose.signIn));

    // Act
    await tester.enterPin('135790');
    await tester.pump();

    // Assert
    expect(pinShown, isTrue);
    expect(find.text('Masukkan PIN kamu'), findsOneWidget);
    expect(repository.calls.where((c) => c == 'verifyEmailOtp'), hasLength(2));
  });

  testWidgets('a wrong PIN shows the attempts left', (tester) async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinRequired, status: 422),
    );
    await pumpCode(tester);
    await typeCode(tester);
    repository.verifyResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinInvalid,
        status: 401,
        extensions: {'attempts_remaining': 4},
      ),
    );

    // Act
    await tester.enterPin('135790');
    await tester.pump();

    // Assert
    expect(find.text('PIN salah. Sisa 4 kali coba.'), findsOneWidget);
  });

  testWidgets('Lupa PIN? opens forgot PIN for the typed address', (tester) async {
    // Arrange
    repository.verifyResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinRequired, status: 422),
    );
    await pumpCode(tester);
    await typeCode(tester);

    // Act
    await tester.tap(find.text('Lupa PIN?'));

    // Assert
    expect(forgotFor, ['rina@gmail.com']);
  });
}
