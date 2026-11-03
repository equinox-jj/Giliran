import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/domain/entities/group_input.dart';
import 'package:giliran/features/group/domain/usecases/create_group_usecase.dart';

import '../../../../helpers/fake_group_repository.dart';

CreateGroupInput _input({String name = 'Arisan RT 05', int amount = 200000, int totalSlots = 10}) => CreateGroupInput(
  name: name,
  amount: amount,
  periodType: PeriodType.monthly,
  totalSlots: totalSlots,
  startDate: DateTime.utc(2026, 11, 25),
  drawMethod: DrawMethod.random,
);

void main() {
  late FakeGroupRepository repository;
  late CreateGroupUseCase useCase;

  setUp(() {
    repository = FakeGroupRepository();
    useCase = CreateGroupUseCase(repository);
  });

  test('creates a valid group with the default reminder of 2 days', () async {
    // Arrange
    final input = _input();

    // Act
    final result = await useCase(input);

    // Assert
    expect(result.isRight(), isTrue);
    expect(repository.lastCreate?.reminderDaysBefore, 2);
  });

  final rejected = <String, (CreateGroupInput, String)>{
    'amount 9.999': (_input(amount: 9999), 'amount'),
    'amount 100.000.001': (_input(amount: 100000001), 'amount'),
    '1 slot': (_input(totalSlots: 1), 'total_slots'),
    '51 slots': (_input(totalSlots: 51), 'total_slots'),
    'a 2-letter name': (_input(name: ' AB '), 'name'),
    'a 61-letter name': (_input(name: 'A' * 61), 'name'),
  };
  for (final MapEntry(key: label, value: (input, field)) in rejected.entries) {
    test('rejects $label before any request', () async {
      // Act
      final result = await useCase(input);

      // Assert
      final failure = result.getLeft().toNullable();
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.single.field, field);
      expect(repository.calls, isEmpty);
    });
  }

  final accepted = <String, CreateGroupInput>{
    'amount 10.000': _input(amount: 10000),
    'amount 100.000.000': _input(amount: 100000000),
    '2 slots': _input(totalSlots: 2),
    '50 slots': _input(totalSlots: 50),
  };
  for (final MapEntry(key: label, value: input) in accepted.entries) {
    test('accepts $label', () async {
      // Act
      final result = await useCase(input);

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, ['createGroup']);
    });
  }
}
