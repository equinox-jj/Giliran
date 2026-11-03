import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/delete_account/page/delete_account_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';

import '../../../../../core/database/fixtures.dart';
import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_profile_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late AppDatabase db;
  late ProviderContainer container;
  late int closeCalls;

  setUp(() async {
    auth = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Rina', pinSet: true));
    profile = FakeProfileRepository();
    db = openTestDatabase();
    await db.groupsDao.upsertAll([groupRow('g1')]);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        profileRepositoryProvider.overrideWithValue(profile),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    closeCalls = 0;
  });

  Future<void> pumpDelete(WidgetTester tester) async {
    await container.read(authSessionControllerProvider.future);
    container.read(authSessionControllerProvider.notifier).unlock();
    await tester.pumpPage(
      DeleteAccountPage(onClose: () => closeCalls++, onForgotPin: () {}),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  AppButton continueButton(WidgetTester tester) => tester.widget<AppButton>(find.widgetWithText(AppButton, 'Lanjut'));

  Future<void> toPinStep(WidgetTester tester) async {
    await tester.tap(find.text('Saya mengerti'));
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
  }

  testWidgets('Lanjut stays off until Saya mengerti is checked', (tester) async {
    // Arrange
    await pumpDelete(tester);
    final offAtStart = continueButton(tester).onPressed == null;

    // Act
    await tester.tap(find.text('Saya mengerti'));
    await tester.pump();

    // Assert
    expect(offAtStart, isTrue);
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('obligations_outstanding shows why and keeps Lanjut off', (tester) async {
    // Arrange
    profile.deleteAccountResult = const Left(
      Failure.conflict(code: ApiErrorCode.obligationsOutstanding),
    );
    await pumpDelete(tester);
    await toPinStep(tester);

    // Act
    await tester.enterPin('123456');
    await tester.pumpAndSettle();

    // Assert
    expect(find.textContaining('Akun belum bisa dihapus'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('pin_invalid shakes the dots with the attempts left', (tester) async {
    // Arrange
    profile.deleteAccountResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinInvalid, status: 401, extensions: {'attempts_remaining': 2}),
    );
    await pumpDelete(tester);
    await toPinStep(tester);

    // Act
    await tester.enterPin('000000');
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('PIN salah. Sisa 2 percobaan.'), findsOneWidget);
    expect(tester.widget<PinPad>(find.byType(PinPad)).error, isTrue);
  });

  testWidgets('success clears the device and Selesai signs out', (tester) async {
    // Arrange
    await pumpDelete(tester);
    await toPinStep(tester);

    // Act
    await tester.enterPin('123456');
    await tester.pumpAndSettle();
    final doneShown = find.text('Selesai').evaluate().isNotEmpty;
    auth.hasSessionResult = const Right(false);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    // Assert
    expect(doneShown, isTrue);
    expect(auth.calls, contains('clearSession'));
    expect(await db.select(db.groups).get(), isEmpty);
    expect(container.read(authSessionControllerProvider).value, isA<AuthSignedOut>());
  });
}
