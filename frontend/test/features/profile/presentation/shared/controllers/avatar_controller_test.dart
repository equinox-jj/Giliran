import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/image_picker_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/photo_source.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/shared/controllers/avatar_controller.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_image_picker_service.dart';
import '../../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late FakeImagePickerService picker;
  late ProviderContainer container;

  AvatarController controller() => container.read(avatarControllerProvider.notifier);
  AvatarState state() => container.read(avatarControllerProvider);

  setUp(() {
    profile = FakeProfileRepository();
    picker = FakeImagePickerService();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(profile),
        imagePickerServiceProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
    container.listen(avatarControllerProvider, (_, _) {});
  });

  test('uploads the picked photo and ends done', () async {
    // Arrange
    final notifier = controller();

    // Act
    final allowed = await notifier.pick(PhotoSource.gallery);

    // Assert
    expect(allowed, isTrue);
    expect(picker.sources, [PhotoSource.gallery]);
    expect(profile.uploadedPaths, ['/tmp/photo.jpg']);
    expect(state().localPath, '/tmp/photo.jpg');
    expect(state().imageUrl, 'https://cdn.test/avatar.jpg');
    expect(state().done, isTrue);
  });

  test('shows the progress while the upload is running', () async {
    // Arrange
    profile
      ..uploadProgress = 0.42
      ..uploadGate = Completer<void>();

    // Act
    final pending = controller().pick(PhotoSource.camera);
    await Future<void>.delayed(Duration.zero);
    final during = state();
    profile.uploadGate!.complete();
    await pending;

    // Assert
    expect(during.uploading, isTrue);
    expect(during.progress, 0.42);
    expect(state().uploading, isFalse);
  });

  test('a cancelled pick changes nothing', () async {
    // Arrange
    picker.next = (path: null, denied: false);

    // Act
    final allowed = await controller().pick(PhotoSource.gallery);

    // Assert
    expect(allowed, isTrue);
    expect(profile.uploadedPaths, isEmpty);
    expect(state().hasPhoto, isFalse);
  });

  test('a blocked permission returns false', () async {
    // Arrange
    picker.next = (path: null, denied: true);

    // Act
    final allowed = await controller().pick(PhotoSource.camera);

    // Assert
    expect(allowed, isFalse);
    expect(profile.uploadedPaths, isEmpty);
  });

  test('a failed upload keeps the photo and retry sends it again', () async {
    // Arrange
    profile.uploadResult = const Left(
      Failure.badRequest(code: ApiErrorCode.fileTooLarge, status: 413),
    );
    await controller().pick(PhotoSource.gallery);
    final failed = state();
    profile.uploadResult = Right(ProfileData(avatarUrl: 'https://cdn.test/avatar.jpg'));

    // Act
    await controller().retry();

    // Assert
    expect(failed.failure?.apiCode, ApiErrorCode.fileTooLarge);
    expect(failed.localPath, '/tmp/photo.jpg');
    expect(profile.uploadedPaths, ['/tmp/photo.jpg', '/tmp/photo.jpg']);
    expect(state().done, isTrue);
  });

  test('remove deletes an uploaded photo', () async {
    // Arrange
    await controller().pick(PhotoSource.gallery);

    // Act
    final failure = await controller().remove();

    // Assert
    expect(failure, isNull);
    expect(profile.deleteCalls, 1);
    expect(state().hasPhoto, isFalse);
  });

  test('remove after a failed upload skips the server', () async {
    // Arrange
    profile.uploadResult = const Left(Failure.network());
    await controller().pick(PhotoSource.gallery);

    // Act
    await controller().remove();

    // Assert
    expect(profile.deleteCalls, 0);
    expect(state().hasPhoto, isFalse);
  });

  test('a refused removal keeps the photo and returns the failure', () async {
    // Arrange
    await controller().pick(PhotoSource.gallery);
    profile.deleteResult = const Left(Failure.network());

    // Act
    final failure = await controller().remove();

    // Assert
    expect(failure, isA<NetworkFailure>());
    expect(state().done, isTrue);
  });
}
