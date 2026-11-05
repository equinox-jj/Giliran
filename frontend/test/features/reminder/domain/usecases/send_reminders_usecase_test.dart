import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/features/reminder/domain/usecases/send_reminders_usecase.dart';

import '../../../../helpers/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository repository;
  late SendRemindersUseCase useCase;

  setUp(() {
    repository = FakeReminderRepository();
    useCase = SendRemindersUseCase(repository);
  });

  test('an empty selection fails locally instead of reminding everyone', () async {
    // Act
    final result = await useCase((groupId: 'g1', periodId: 'p1', memberIds: const [], key: const IdempotencyKey('k')));

    // Assert
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(repository.calls, isEmpty);
  });

  test('sends the selected ids with the key', () async {
    // Act
    await useCase((groupId: 'g1', periodId: 'p1', memberIds: const ['m4', 'm7'], key: const IdempotencyKey('k1')));

    // Assert
    expect(repository.calls, ['sendReminders']);
    expect(repository.memberIds.single, ['m4', 'm7']);
    expect(repository.keys.single, 'k1');
  });
}
