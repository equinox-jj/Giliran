import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/group/domain/entities/group_input.dart';
import 'package:giliran/features/group/domain/usecases/update_group_usecase.dart';

import '../../../../helpers/fake_group_repository.dart';

void main() {
  late FakeGroupRepository repository;
  late UpdateGroupUseCase useCase;

  setUp(() {
    repository = FakeGroupRepository();
    useCase = UpdateGroupUseCase(repository);
  });

  test('an empty change sends nothing', () async {
    // Act
    final result = await useCase((groupId: 'g1', input: const UpdateGroupInput()));

    // Assert
    expect(result.getOrElse((_) => throw StateError('')), isNull);
    expect(repository.calls, isEmpty);
  });

  test('rejects a reminder of 8 days before any request', () async {
    // Act
    final result = await useCase((groupId: 'g1', input: const UpdateGroupInput(reminderDaysBefore: 8)));

    // Assert
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(repository.calls, isEmpty);
  });

  test('sends a valid name change', () async {
    // Act
    await useCase((groupId: 'g1', input: const UpdateGroupInput(name: 'Arisan Baru')));

    // Assert
    expect(repository.lastUpdate?.name, 'Arisan Baru');
  });
}
