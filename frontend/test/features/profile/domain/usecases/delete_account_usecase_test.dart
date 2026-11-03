import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/profile/domain/usecases/delete_account_usecase.dart';

import '../../../../core/database/fixtures.dart';
import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late FakeAuthRepository auth;
  late AppDatabase db;
  late DeleteAccountUseCase useCase;

  setUp(() async {
    profile = FakeProfileRepository();
    auth = FakeAuthRepository();
    db = openTestDatabase();
    addTearDown(db.close);
    await db.groupsDao.upsertAll([groupRow('g1')]);
    useCase = DeleteAccountUseCase(profile, auth, db);
  });

  test('success clears the session and the offline cache', () async {
    // Arrange
    const pin = '123456';

    // Act
    final result = await useCase(pin);

    // Assert
    expect(result.isRight(), isTrue);
    expect(profile.deletedWithPins, [pin]);
    expect(auth.calls, contains('clearSession'));
    expect(await db.select(db.groups).get(), isEmpty);
  });

  test('a refusal keeps everything on the device', () async {
    // Arrange
    profile.deleteAccountResult = const Left(
      Failure.conflict(code: ApiErrorCode.obligationsOutstanding),
    );

    // Act
    final result = await useCase('123456');

    // Assert
    expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.obligationsOutstanding);
    expect(auth.calls, isNot(contains('clearSession')));
    expect(await db.select(db.groups).get(), hasLength(1));
  });

  test('a failed local clear still reports success', () async {
    // Arrange
    auth.clearSessionResult = const Left(Failure.cache());

    // Act
    final result = await useCase('123456');

    // Assert
    expect(result.isRight(), isTrue);
    expect(await db.select(db.groups).get(), isEmpty);
  });
}
