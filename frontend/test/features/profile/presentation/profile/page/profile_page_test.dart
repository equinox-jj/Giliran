import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/profile/page/profile_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;
  late List<String> opened;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Giliran',
      packageName: 'id.giliran',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    );
    auth = FakeAuthRepository()
      ..userResult = Right(
        ProfileData(
          name: 'Rina Ayu',
          email: 'rina@email.com',
          phone: '+6281234567890',
          pinSet: true,
        ),
      );
    container = authTestContainer(auth);
    opened = [];
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await container.read(authSessionControllerProvider.future);
    container.read(authSessionControllerProvider.notifier).unlock();
    await tester.pumpPage(
      ProfilePage(
        onEdit: () => opened.add('edit'),
        onSecurity: () => opened.add('security'),
        onSettings: () => opened.add('settings'),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the name, email and WhatsApp number', (tester) async {
    // Arrange
    await pumpProfile(tester);

    // Act
    final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));

    // Assert
    expect(find.text('Rina Ayu'), findsOneWidget);
    expect(find.text('rina@email.com'), findsOneWidget);
    expect(find.text('+62 812-3456-7890'), findsOneWidget);
    expect(avatar.size, 80);
  });

  testWidgets('hides the number when none is set', (tester) async {
    // Arrange
    auth.userResult = Right(ProfileData(name: 'Rina', email: 'rina@email.com', pinSet: true));

    // Act
    await pumpProfile(tester);

    // Assert
    expect(find.textContaining('+62'), findsNothing);
  });

  testWidgets('lists the account, help and about rows with the version', (tester) async {
    // Arrange
    await pumpProfile(tester);

    // Act
    await tester.scrollUntilVisible(find.text('Versi app'), 200);

    // Assert
    for (final label in [
      'Keamanan',
      'Pengaturan',
      'Cara kerja kocokan',
      'Kenapa Giliran tidak memegang uang',
      'Hubungi kami',
      'Kebijakan privasi',
      'Syarat',
      'Versi app',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('1.0.0 (7)'), findsOneWidget);
  });

  testWidgets('Ubah profil, Keamanan and Pengaturan open their screens', (tester) async {
    // Arrange
    await pumpProfile(tester);

    // Act
    await tester.tap(find.text('Ubah profil'));
    await tester.tap(find.text('Keamanan'));
    await tester.tap(find.text('Pengaturan'));

    // Assert
    expect(opened, ['edit', 'security', 'settings']);
  });

  testWidgets('a help row opens its explanation sheet', (tester) async {
    // Arrange
    await pumpProfile(tester);

    // Act
    await tester.tap(find.text('Cara kerja kocokan'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Mengerti'), findsOneWidget);
  });

  testWidgets('Keluar asks first and signs out on confirm', (tester) async {
    // Arrange
    await pumpProfile(tester);
    await tester.scrollUntilVisible(find.text('Keluar'), 200);

    // Act
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    final asked = find.text('Keluar dari Giliran?').evaluate().isNotEmpty;
    await tester.tap(find.text('Keluar').last);
    await tester.pumpAndSettle();

    // Assert
    expect(asked, isTrue);
    expect(auth.calls, containsAllInOrder(['logout', 'clearSession']));
    expect(container.read(authSessionControllerProvider).value, isA<AuthSignedOut>());
  });

  testWidgets('cancelling Keluar keeps the session', (tester) async {
    // Arrange
    await pumpProfile(tester);
    await tester.scrollUntilVisible(find.text('Keluar'), 200);

    // Act
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Assert
    expect(auth.calls, isNot(contains('logout')));
    expect(container.read(authSessionControllerProvider).value, isA<AuthUnlocked>());
  });
}
