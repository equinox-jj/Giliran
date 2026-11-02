import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/biometric_kind.dart';
import 'package:giliran/features/auth/presentation/biometric_opt_in/page/biometric_opt_in_page.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeBiometricService biometric;
  late ProviderContainer container;
  late int done;

  setUp(() {
    repository = FakeAuthRepository();
    biometric = FakeBiometricService()..kind = BiometricKind.fingerprint;
    container = authTestContainer(repository, biometric: biometric);
    done = 0;
  });

  Future<void> pumpOptIn(WidgetTester tester) async {
    await tester.pumpPage(
      BiometricOptInPage(onDone: () => done++),
      container: container,
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('moves on at once when no biometric is enrolled', (tester) async {
    // Arrange
    biometric.kind = null;

    // Act
    await pumpOptIn(tester);

    // Assert
    expect(done, 1);
    expect(find.text('Aktifkan'), findsNothing);
  });

  testWidgets('moves on at once when it was offered before', (tester) async {
    // Arrange
    repository.savedBiometricPrompted = true;

    // Act
    await pumpOptIn(tester);

    // Assert
    expect(done, 1);
  });

  testWidgets('offers the fingerprint and turns it on', (tester) async {
    // Arrange
    await pumpOptIn(tester);
    final offered = find.text('Buka Giliran dengan sidik jari').evaluate().isNotEmpty;

    // Act
    await tester.tap(find.text('Aktifkan'));
    await tester.pump();
    await tester.pump();

    // Assert
    expect(offered, isTrue);
    expect(repository.savedBiometricEnabled, isTrue);
    expect(repository.savedBiometricPrompted, isTrue);
    expect(done, 1);
  });

  testWidgets('Nanti saja keeps it off and is not asked again', (tester) async {
    // Arrange
    await pumpOptIn(tester);

    // Act
    await tester.tap(find.text('Nanti saja'));
    await tester.pump();
    await tester.pump();

    // Assert
    expect(repository.savedBiometricEnabled, isFalse);
    expect(repository.savedBiometricPrompted, isTrue);
    expect(done, 1);
  });
}
