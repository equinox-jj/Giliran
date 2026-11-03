import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/code_formatter.dart';

void main() {
  group('grouped', () {
    test('groups a 10-character code in fours', () {
      // Arrange
      const code = '7H2K9QX4MP';

      // Act
      final result = CodeFormatter.grouped(code);

      // Assert
      expect(result, '7H2K 9QX4 MP');
    });

    test('leaves an exact multiple of four without a trailing space', () {
      // Arrange
      const code = 'K7P2QX9M';

      // Act
      final result = CodeFormatter.grouped(code);

      // Assert
      expect(result, 'K7P2 QX9M');
    });

    test('returns an empty code unchanged', () {
      // Arrange
      const code = '';

      // Act
      final result = CodeFormatter.grouped(code);

      // Assert
      expect(result, '');
    });
  });

  group('hashShort', () {
    test('keeps the first and last four characters of a 64-char hash', () {
      // Arrange
      final hash = '9f2c${'0' * 56}a71e';

      // Act
      final result = CodeFormatter.hashShort(hash);

      // Assert
      expect(hash.length, 64);
      expect(result, '9f2c…a71e');
    });

    test('returns a short value unchanged', () {
      // Arrange
      const hash = 'abc123';

      // Act
      final result = CodeFormatter.hashShort(hash);

      // Assert
      expect(result, 'abc123');
    });
  });

  group('slotNo', () {
    test('pads single digits to two', () {
      // Arrange
      const slot = 7;

      // Act
      final result = CodeFormatter.slotNo(slot);

      // Assert
      expect(result, '07');
    });

    test('keeps two digits', () {
      // Arrange
      const slot = 50;

      // Act
      final result = CodeFormatter.slotNo(slot);

      // Assert
      expect(result, '50');
    });
  });
}
