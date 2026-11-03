import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/usecase/usecase.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/domain/usecases/delete_avatar_usecase.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late FakeAuthRepository auth;
  late DeleteAvatarUseCase useCase;

  setUp(() {
    profile = FakeProfileRepository();
    auth = FakeAuthRepository()
      ..userResult = Right(
        ProfileData(name: 'Rina', avatarUrl: 'https://cdn.test/a.jpg'),
      );
    useCase = DeleteAvatarUseCase(profile, auth);
  });

  test('removes the photo and clears it from the cached user', () async {
    // Arrange
    const params = NoParams();

    // Act
    final result = await useCase(params);

    // Assert
    expect(result.isRight(), isTrue);
    expect(profile.deleteCalls, 1);
    expect(auth.savedUser?.name, 'Rina');
    expect(auth.savedUser?.avatarUrl, isNull);
  });

  test('keeps the cache as it is when the server refuses', () async {
    // Arrange
    profile.deleteResult = const Left(Failure.network());

    // Act
    final result = await useCase(const NoParams());

    // Assert
    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    expect(auth.savedUser, isNull);
  });
}
