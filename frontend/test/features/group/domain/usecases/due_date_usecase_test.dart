import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/domain/usecases/due_date_usecase.dart';

void main() {
  const useCase = DueDateUseCase();

  test('period 1 is the start date', () {
    // Arrange
    final start = DateTime.utc(2026, 11);

    // Act
    final due = useCase(start: start, periodType: PeriodType.monthly, periodNo: 1);

    // Assert
    expect(due, start);
  });

  test('weekly adds 7 days per period', () {
    // Arrange
    final start = DateTime.utc(2026, 11);

    // Act
    final due = useCase(start: start, periodType: PeriodType.weekly, periodNo: 8);

    // Assert
    expect(due, DateTime.utc(2026, 12, 20));
  });

  test('monthly keeps the day of month across the year end', () {
    // Arrange
    final start = DateTime.utc(2026, 11, 15);

    // Act
    final due = useCase(start: start, periodType: PeriodType.monthly, periodNo: 3);

    // Assert
    expect(due, DateTime.utc(2027, 1, 15));
  });

  test('monthly clamps to a shorter month without carrying over', () {
    // Arrange
    final start = DateTime.utc(2027, 1, 31);

    // Act
    final feb = useCase(start: start, periodType: PeriodType.monthly, periodNo: 2);
    final mar = useCase(start: start, periodType: PeriodType.monthly, periodNo: 3);

    // Assert
    expect(feb, DateTime.utc(2027, 2, 28));
    expect(mar, DateTime.utc(2027, 3, 31));
  });
}
