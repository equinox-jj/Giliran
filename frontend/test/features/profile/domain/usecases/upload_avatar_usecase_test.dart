import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/profile/domain/usecases/upload_avatar_usecase.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late FakeAuthRepository auth;
  late UploadAvatarUseCase useCase;

  setUp(() {
    profile = FakeProfileRepository();
    auth = FakeAuthRepository();
    useCase = UploadAvatarUseCase(profile, auth);
  });

  test('uploads the file, reports progress and caches the user', () async {
    // Arrange
    final progress = <double>[];

    // Act
    final result = await useCase((path: '/tmp/a.jpg', onProgress: progress.add));

    // Assert
    expect(result.isRight(), isTrue);
    expect(profile.uploadedPaths, ['/tmp/a.jpg']);
    expect(progress, [0.5]);
    expect(auth.savedUser?.avatarUrl, 'https://cdn.test/avatar.jpg');
  });

  test('keeps the cache as it is when the upload fails', () async {
    // Arrange
    profile.uploadResult = const Left(
      Failure.badRequest(code: ApiErrorCode.fileTooLarge, status: 413),
    );

    // Act
    final result = await useCase((path: '/tmp/a.jpg', onProgress: null));

    // Assert
    expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.fileTooLarge);
    expect(auth.savedUser, isNull);
  });
}
