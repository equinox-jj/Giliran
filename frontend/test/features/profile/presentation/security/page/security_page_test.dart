import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/session.dart';
import 'package:giliran/features/profile/presentation/security/page/security_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_profile_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeBiometricService biometric;
  late ProviderContainer container;
  late List<String> opened;

  final sessions = [
    Session(id: 'me', deviceName: 'Pixel 8', devicePlatform: 'android', isCurrent: true),
    Session(
      id: 'tablet',
      deviceName: 'Galaxy Tab',
      devicePlatform: 'android',
      lastActiveAt: DateTime.utc(2026, 11, 1, 8),
      isCurrent: false,
    ),
  ];

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository()..sessionsResult = Right(sessions);
    biometric = FakeBiometricService();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(biometric),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    opened = [];
  });

  Future<void> pumpSecurity(WidgetTester tester) async {
    await tester.pumpPage(
      SecurityPage(
        onChangePin: () => opened.add('pin'),
        onChangeEmail: () => opened.add('email'),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the sessions with "Perangkat ini" on the current one', (tester) async {
    // Arrange
    await pumpSecurity(tester);

    // Act
    final current = find.ancestor(of: find.text('Pixel 8'), matching: find.byType(SessionRow));

    // Assert
    expect(find.byType(SessionRow), findsNWidgets(2));
    expect(find.descendant(of: current, matching: find.text('Perangkat ini')), findsOneWidget);
    expect(find.descendant(of: current, matching: find.text('Keluarkan')), findsNothing);
    expect(find.text('Keluar dari semua perangkat lain'), findsOneWidget);
  });

  testWidgets('Keluarkan confirms, then signs that device out', (tester) async {
    // Arrange
    await pumpSecurity(tester);

    // Act
    await tester.tap(find.text('Keluarkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluarkan').last);
    await tester.pumpAndSettle();

    // Assert
    expect(profile.revokedIds, ['tablet']);
    expect(find.text('Galaxy Tab'), findsNothing);
  });

  testWidgets('signing out all others reports the count', (tester) async {
    // Arrange
    await pumpSecurity(tester);

    // Act
    await tester.tap(find.text('Keluar dari semua perangkat lain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluarkan').last);
    await tester.pumpAndSettle();

    // Assert
    expect(profile.revokedIds, ['tablet']);
    expect(find.text('1 perangkat dikeluarkan.'), findsOneWidget);
  });

  testWidgets('the biometric toggle saves the choice', (tester) async {
    // Arrange
    await pumpSecurity(tester);

    // Act
    await tester.tap(find.text('Buka dengan sidik jari'));
    await tester.pumpAndSettle();

    // Assert
    expect(auth.savedBiometricEnabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('hides the biometric row without biometrics', (tester) async {
    // Arrange
    biometric.kind = null;

    // Act
    await pumpSecurity(tester);

    // Assert
    expect(find.textContaining('Buka dengan'), findsNothing);
  });

  testWidgets('Ubah PIN and Ubah email open their flows', (tester) async {
    // Arrange
    await pumpSecurity(tester);

    // Act
    await tester.tap(find.text('Ubah PIN'));
    await tester.tap(find.text('Ubah email'));

    // Assert
    expect(opened, ['pin', 'email']);
  });

  testWidgets('a failed load offers Coba lagi', (tester) async {
    // Arrange
    profile.sessionsResult = const Left(Failure.network());
    await pumpSecurity(tester);
    profile.sessionsResult = Right(sessions);

    // Act
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.byType(SessionRow), findsNWidgets(2));
  });
}
