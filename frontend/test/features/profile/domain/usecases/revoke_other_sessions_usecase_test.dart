import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/profile/domain/entity/session.dart';
import 'package:giliran/features/profile/domain/usecases/revoke_other_sessions_usecase.dart';

import '../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late RevokeOtherSessionsUseCase useCase;

  const sessions = [
    Session(id: 'me', isCurrent: true),
    Session(id: 'tablet', isCurrent: false),
    Session(id: 'old-phone', isCurrent: false),
  ];

  setUp(() {
    profile = FakeProfileRepository();
    useCase = RevokeOtherSessionsUseCase(profile);
  });

  test('revoke other sessions skips the current one', () async {
    // Arrange
    const input = sessions;

    // Act
    final result = await useCase(input);

    // Assert
    expect(result, const Right<Failure, int>(2));
    expect(profile.revokedIds, ['tablet', 'old-phone']);
  });

  test('stops at the first failure', () async {
    // Arrange
    profile.revokeResults['tablet'] = const Left(Failure.network());

    // Act
    final result = await useCase(sessions);

    // Assert
    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    expect(profile.revokedIds, ['tablet']);
  });

  test('revokes nothing when only this device is signed in', () async {
    // Arrange
    const input = [Session(id: 'me', isCurrent: true)];

    // Act
    final result = await useCase(input);

    // Assert
    expect(result, const Right<Failure, int>(0));
    expect(profile.revokedIds, isEmpty);
  });
}
