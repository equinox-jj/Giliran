import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/domain/usecases/update_me_usecase.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late FakeAuthRepository auth;
  late UpdateMeUseCase useCase;

  setUp(() {
    profile = FakeProfileRepository();
    auth = FakeAuthRepository();
    useCase = UpdateMeUseCase(profile, auth);
  });

  test('trims the name, drops an empty phone and caches the user', () async {
    // Arrange
    const params = (name: '  Rina Ayu ', phone: ' ');

    // Act
    final result = await useCase(params);

    // Assert
    expect(result.isRight(), isTrue);
    expect(profile.lastUpdate, (name: 'Rina Ayu', phone: null));
    expect(auth.savedUser?.name, 'Rina Ayu');
  });

  test('keeps the cache as it is when the server rejects it', () async {
    // Arrange
    profile.updateResult = const Left(Failure.validation());

    // Act
    final result = await useCase((name: 'R', phone: null));

    // Assert
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(auth.savedUser, isNull);
  });

  test('sends the phone in E.164 as given', () async {
    // Arrange
    const phone = '+6281234567890';

    // Act
    await useCase((name: 'Rina', phone: phone));

    // Assert
    expect(profile.lastUpdate?.phone, phone);
    expect(auth.savedUser, isA<ProfileData>());
  });
}
