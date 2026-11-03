import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/presentation/fill_name/page/fill_name_page.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
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

  setUp(() {
    auth = FakeAuthRepository()..userResult = Right(ProfileData(pinSet: false));
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
  });

  Future<void> pumpName(WidgetTester tester) => tester.pumpPage(const FillNamePage(), container: container);

  Future<void> pickFromGallery(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: find.byType(AvatarPicker), matching: find.byType(Pressable)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeri'));
    await tester.pump();
  }

  AppButton next(WidgetTester tester) => tester.widget<AppButton>(find.widgetWithText(AppButton, 'Lanjut'));

  testWidgets('Lanjut turns on from two characters', (tester) async {
    // Arrange
    await pumpName(tester);
    final offWhenEmpty = next(tester).onPressed == null;

    // Act
    await tester.enterText(find.byType(TextField).first, 'Ri');
    await tester.pump();

    // Assert
    expect(offWhenEmpty, isTrue);
    expect(next(tester).onPressed, isNotNull);
  });

  testWidgets('saves the name and the phone in E.164', (tester) async {
    // Arrange
    await pumpName(tester);
    await tester.enterText(find.byType(TextField).first, 'Rina');
    await tester.enterText(find.byType(TextField).last, '081234567890');

    // Act
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Assert
    expect(profile.lastUpdate, (name: 'Rina', phone: '+6281234567890'));
    expect(auth.savedUser?.name, 'Rina');
  });

  testWidgets('a bad phone number stops the save', (tester) async {
    // Arrange
    await pumpName(tester);
    await tester.enterText(find.byType(TextField).first, 'Rina');
    await tester.enterText(find.byType(TextField).last, '0812');

    // Act
    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    // Assert
    expect(find.text('Nomor WhatsApp belum benar'), findsOneWidget);
    expect(profile.lastUpdate, isNull);
  });

  testWidgets('shows the server message under the name', (tester) async {
    // Arrange
    profile.updateResult = const Left(
      Failure.validation(
        fieldErrors: [FieldError(field: 'name', code: 'min_length', message: 'Nama minimal 2 huruf')],
      ),
    );
    await pumpName(tester);
    await tester.enterText(find.byType(TextField).first, 'Ri');

    // Act
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Nama minimal 2 huruf'), findsOneWidget);
  });

  testWidgets('uploads the photo picked from Galeri', (tester) async {
    // Arrange
    await pumpName(tester);

    // Act
    await pickFromGallery(tester);
    await tester.pumpAndSettle();

    // Assert
    expect(profile.uploadedPaths, ['/tmp/photo.jpg']);
    expect(find.text('Ketuk untuk ganti'), findsOneWidget);
  });

  testWidgets('Lanjut waits while the photo uploads', (tester) async {
    // Arrange
    profile.uploadGate = Completer<void>();
    await pumpName(tester);
    await tester.enterText(find.byType(TextField).first, 'Rina');

    // Act
    await pickFromGallery(tester);
    await tester.pump();
    final during = next(tester).onPressed;
    final progressShown = find.text('Mengunggah… 50%').evaluate().isNotEmpty;
    profile.uploadGate!.complete();
    await tester.pumpAndSettle();

    // Assert
    expect(during, isNull);
    expect(progressShown, isTrue);
    expect(next(tester).onPressed, isNotNull);
  });

  testWidgets('a failed upload shows why and offers Coba lagi', (tester) async {
    // Arrange
    profile.uploadResult = const Left(
      Failure.badRequest(code: ApiErrorCode.fileTooLarge, status: 413),
    );
    await pumpName(tester);

    // Act
    await pickFromGallery(tester);
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Foto lebih dari 5 MB. Pilih foto lain.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
