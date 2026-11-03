import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/money_formatter.dart';

void main() {
  group('MoneyFormatter.rupiah', () {
    for (final (amount, expected) in [
      (0, 'Rp0'),
      (10000, 'Rp10.000'),
      (1234567, 'Rp1.234.567'),
      (100000000, 'Rp100.000.000'),
    ]) {
      test('$amount → $expected', () {
        // Arrange
        final input = amount;

        // Act
        final result = MoneyFormatter.rupiah(input);

        // Assert
        expect(result, expected);
      });
    }
  });
}
