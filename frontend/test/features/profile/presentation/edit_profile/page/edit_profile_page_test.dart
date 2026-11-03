import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/edit_profile/page/edit_profile_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_image_picker_service.dart';
import '../../../../../helpers/fake_profile_repository.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late ProviderContainer container;
  late int changeEmailTaps;
  late int doneCalls;

  setUp(() {
    auth = FakeAuthRepository()
      ..userResult = Right(
        ProfileData(
          name: 'Rina',
          email: 'rina@email.com',
          phone: '+6281234567890',
          pinSet: true,
        ),
      );
    profile = FakeProfileRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        profileRepositoryProvider.overrideWithValue(profile),
        imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
      ],
    );
    addTearDown(container.dispose);
    changeEmailTaps = 0;
    doneCalls = 0;
  });

  Future<void> pumpEdit(WidgetTester tester) async {
    await container.read(authSessionControllerProvider.future);
    container.read(authSessionControllerProvider.notifier).unlock();
    await tester.pumpPage(
      EditProfilePage(
        onChangeEmail: () => changeEmailTaps++,
        onDone: () => doneCalls++,
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  AppButton save(WidgetTester tester) => tester.widget<AppButton>(find.widgetWithText(AppButton, 'Simpan'));

  Finder nameField() => find.byType(TextField).first;

  Finder phoneField() => find.byType(TextField).last;

  testWidgets('Simpan stays off until a field changes', (tester) async {
    // Arrange
    await pumpEdit(tester);
    final offAtStart = save(tester).onPressed == null;

    // Act
    await tester.enterText(nameField(), 'Rina Ayu');
    await tester.pump();

    // Assert
    expect(offAtStart, isTrue);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('a one-character name shows the 2–50 error and does not save', (tester) async {
    // Arrange
    await pumpEdit(tester);
    await tester.enterText(nameField(), 'R');
    await tester.pump();

    // Act
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    // Assert
    expect(find.text('Nama harus 2–50 karakter.'), findsOneWidget);
    expect(profile.lastUpdate, isNull);
  });

  testWidgets('sends only the changed name', (tester) async {
    // Arrange
    await pumpEdit(tester);
    await tester.enterText(nameField(), 'Rina Ayu');
    await tester.pump();

    // Act
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Assert
    expect(profile.lastUpdate, (name: 'Rina Ayu', phone: null));
    expect(profile.lastClearPhone, isFalse);
    expect(doneCalls, 1);
  });

  testWidgets('clearing the phone sends phone null', (tester) async {
    // Arrange
    await pumpEdit(tester);
    await tester.tap(find.byType(FieldClearButton));
    await tester.pump();

    // Act
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Assert
    expect(profile.lastClearPhone, isTrue);
    expect(profile.lastUpdate, (name: null, phone: null));
  });

  testWidgets('a bad phone number stops the save', (tester) async {
    // Arrange
    await pumpEdit(tester);
    await tester.enterText(phoneField(), '0812');
    await tester.pump();

    // Act
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    // Assert
    expect(find.text('Nomor WhatsApp belum benar'), findsOneWidget);
    expect(profile.lastUpdate, isNull);
  });

  testWidgets('shows the email read-only and Ubah opens Change email', (tester) async {
    // Arrange
    await pumpEdit(tester);

    // Act
    await tester.tap(find.text('Ubah'));

    // Assert
    expect(find.text('rina@email.com'), findsOneWidget);
    expect(changeEmailTaps, 1);
  });

  testWidgets('the avatar sheet offers Hapus foto for the current photo', (tester) async {
    // Arrange
    auth.userResult = Right(
      ProfileData(name: 'Rina', email: 'rina@email.com', avatarUrl: 'https://cdn.test/a.jpg', pinSet: true),
    );
    await pumpEdit(tester);

    // Act
    await tester.tap(
      find.descendant(of: find.byType(AvatarPicker), matching: find.byType(Pressable)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus foto'));
    await tester.pumpAndSettle();

    // Assert
    expect(profile.deleteCalls, 1);
  });
}
