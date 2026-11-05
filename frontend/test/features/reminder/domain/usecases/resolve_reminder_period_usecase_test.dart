import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/reminder/domain/usecases/resolve_reminder_period_usecase.dart';

import '../../../../helpers/fake_group_repository.dart';

void main() {
  late FakeGroupRepository groups;
  late ResolveReminderPeriodUseCase useCase;

  setUp(() {
    groups = FakeGroupRepository();
    useCase = ResolveReminderPeriodUseCase(groups);
  });

  test("returns the group's current period, fetched fresh", () async {
    // Arrange
    groups.groupResult = const Right(GroupDetail(id: 'g1', currentPeriodId: 'p4'));

    // Act
    final result = await useCase('g1');

    // Assert
    expect(result.toNullable(), 'p4');
    expect(groups.calls, ['refreshGroup']);
  });

  test('a group without a running period fails with period_not_open', () async {
    // Arrange
    groups.groupResult = const Right(GroupDetail(id: 'g1'));

    // Act
    final result = await useCase('g1');

    // Assert
    expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.periodNotOpen);
  });

  test('a failed refresh passes its failure through', () async {
    // Arrange
    groups.groupResult = const Left(Failure.network());

    // Act
    final result = await useCase('g1');

    // Assert
    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });
}
