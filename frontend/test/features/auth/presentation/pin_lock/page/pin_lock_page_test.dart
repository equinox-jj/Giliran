import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/pin_lock/page/pin_lock_page.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeBiometricService biometric;
  late ProviderContainer container;
  late List<String?> forgotFor;

  const wrongPin = Left<Failure, Unit>(
    Failure.badRequest(
      code: ApiErrorCode.pinInvalid,
      status: 401,
      extensions: {'attempts_remaining': 2},
    ),
  );

  setUp(() {
    repository = FakeAuthRepository()
      ..userResult = Right(
        ProfileData(name: 'Rina Ayu', email: 'rina@gmail.com', pinSet: true),
      );
    biometric = FakeBiometricService();
    container = authTestContainer(repository, biometric: biometric);
    forgotFor = [];
  });

  Future<void> pumpLock(WidgetTester tester) async {
    await container.read(authSessionControllerProvider.future);
    await tester.pumpPage(
      PinLockPage(onForgotPin: forgotFor.add),
      container: container,
      size: const Size(390, 1000),
    );
    await tester.pump();
    await tester.pump();
  }

  AuthStatus? status() => container.read(authSessionControllerProvider).value;

  testWidgets('greets the user by first name', (tester) async {
    // Arrange
    // (a locked session)

    // Act
    await pumpLock(tester);

    // Assert
    expect(find.text('Halo, Rina'), findsOneWidget);
    expect(status(), isA<AuthLocked>());
  });

  testWidgets('a correct PIN unlocks the session', (tester) async {
    // Arrange
    await pumpLock(tester);

    // Act
    await tester.enterPin('135790');
    await tester.pump();

    // Assert
    expect(repository.calls, contains('verifyPin'));
    expect(status(), isA<AuthUnlocked>());
  });

  testWidgets('a wrong PIN says so, with attempts from the third try', (tester) async {
    // Arrange
    repository.unitResult = wrongPin;
    await pumpLock(tester);
    await tester.enterPin('111111');
    await tester.pump();
    final firstMessage = find.text('PIN salah.').evaluate().isNotEmpty;

    // Act
    await tester.enterPin('222222');
    await tester.pump();
    await tester.enterPin('333333');
    await tester.pump();

    // Assert
    expect(firstMessage, isTrue);
    expect(find.text('PIN salah. Sisa 2 percobaan.'), findsOneWidget);
    expect(status(), isA<AuthLocked>());
  });

  testWidgets('pin_locked shows the countdown instead of the pad', (tester) async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinLocked,
        status: 423,
        retryAfter: Duration(minutes: 15),
      ),
    );
    await pumpLock(tester);

    // Act
    await tester.enterPin('111111');
    await tester.pump();

    // Assert
    expect(find.byType(CountdownText), findsOneWidget);
    expect(find.byType(PinPad), findsNothing);
  });

  testWidgets('prompts the biometric on open when it is on', (tester) async {
    // Arrange
    repository.savedBiometricEnabled = true;

    // Act
    await pumpLock(tester);
    await tester.pump();

    // Assert
    expect(biometric.authenticateCalls, 1);
    expect(status(), isA<AuthUnlocked>());
  });

  testWidgets('does not prompt the biometric when it is off', (tester) async {
    // Arrange
    // (biometric off by default)

    // Act
    await pumpLock(tester);

    // Assert
    expect(biometric.authenticateCalls, 0);
  });

  testWidgets('Lupa PIN? opens forgot PIN with the account email', (tester) async {
    // Arrange
    await pumpLock(tester);

    // Act
    await tester.tap(find.text('Lupa PIN?'));

    // Assert
    expect(forgotFor, ['rina@gmail.com']);
  });

  testWidgets('Keluar signs out after the confirm dialog', (tester) async {
    // Arrange
    await pumpLock(tester);
    await tester.tap(find.text('Bukan kamu? Keluar'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Keluar').last);
    await tester.pumpAndSettle();

    // Assert
    expect(repository.calls, contains('logout'));
    expect(status(), isA<AuthSignedOut>());
  });

  group('fits the screen', () {
    const screens = {
      'small phone': Size(320, 568),
      'phone': Size(390, 844),
      'phone landscape': Size(844, 390),
      'tablet landscape': Size(1180, 820),
    };
    // Below the 360 dp floor the pad scrolls instead of shrinking its keys
    // under the tap minimum: there, each part only has to scroll into view.
    const scrolls = {'small phone'};
    for (final MapEntry(key: name, value: size) in screens.entries) {
      testWidgets('on a $name', (tester) async {
        // Arrange
        await container.read(authSessionControllerProvider.future);

        // Act
        await tester.pumpPage(
          PinLockPage(onForgotPin: forgotFor.add),
          container: container,
          size: size,
        );
        await tester.pump();
        await tester.pump();

        final keypad = find.bySemanticsLabel('Hapus');
        final logout = find.text('Bukan kamu? Keluar');
        if (scrolls.contains(name)) await tester.ensureVisible(keypad);
        final keypadBottom = tester.getBottomLeft(keypad).dy;
        if (scrolls.contains(name)) await tester.ensureVisible(logout);
        final logoutBottom = tester.getBottomLeft(logout).dy;

        // Assert
        expect(tester.takeException(), isNull);
        expect(keypadBottom, lessThanOrEqualTo(size.height));
        expect(logoutBottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}
