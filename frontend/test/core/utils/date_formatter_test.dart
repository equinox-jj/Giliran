import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/date_formatter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('jakarta', () {
    test('a UTC evening is the next morning in Jakarta', () {
      // Arrange
      final utc = DateTime.utc(2026, 10, 24, 18, 30);

      // Act
      final result = AppDate.jakarta(utc);

      // Assert
      expect((result.year, result.month, result.day), (2026, 10, 25));
      expect((result.hour, result.minute), (1, 30));
    });

    test('shows the Jakarta date for a timestamp just before UTC midnight', () {
      // Arrange
      final utc = DateTime.utc(2026, 12, 31, 23, 59);

      // Act
      final result = AppDate.short(AppDate.jakarta(utc), now: DateTime.utc(2027, 1, 1));

      // Assert
      expect(result, 'Jum, 1 Jan');
    });
  });

  group('short', () {
    test('Dec 31 viewed on Jan 1 uses the other-year format', () {
      // Arrange
      final d = DateTime(2025, 12, 31);

      // Act
      final result = AppDate.short(d, now: DateTime(2026, 1, 1));

      // Assert
      expect(result, '31 Des 2025');
    });

    test('a date this year shows the weekday and no year', () {
      // Arrange
      final d = DateTime(2026, 10, 25);

      // Act
      final result = AppDate.short(d, now: DateTime(2026, 11, 3));

      // Assert
      expect(result, 'Min, 25 Okt');
    });
  });

  group('smart', () {
    // Server instants in UTC; comments give the Jakarta (UTC+7) wall clock.
    final now = DateTime.utc(2026, 11, 3, 7); // Sel, 3 Nov 14.00

    for (final (label, d, expected) in [
      ('30 s ago', DateTime.utc(2026, 11, 3, 6, 59, 30), 'Baru saja'),
      ('15 min ago', DateTime.utc(2026, 11, 3, 6, 45), '15 menit lalu'),
      ('2 h ago', DateTime.utc(2026, 11, 3, 5), '2 jam lalu'),
      ('in 3 h', DateTime.utc(2026, 11, 3, 10), '3 jam lagi'),
      ('in 20 min', DateTime.utc(2026, 11, 3, 7, 20), '20 menit lagi'),
      ('yesterday', DateTime.utc(2026, 11, 2, 13), 'Kemarin'), // 2 Nov 20.00
      ('tomorrow', DateTime.utc(2026, 11, 4, 2), 'Besok'), // 4 Nov 09.00
      ('two calendar days ago within 48 h', DateTime.utc(2026, 11, 1, 16), 'Min, 1 Nov'), // 1 Nov 23.00
      ('48 h or more ago', DateTime.utc(2026, 11, 1, 7), 'Min, 1 Nov'),
      ('next year', DateTime.utc(2027, 1, 9, 17), '10 Jan 2027'), // 10 Jan 2027 00.00
    ]) {
      test('$label → $expected', () {
        // Arrange
        final input = d;

        // Act
        final result = AppDate.smart(input, now: now);

        // Assert
        expect(result, expected);
      });
    }

    test('uses Jakarta days when UTC days differ but Jakarta days match', () {
      // Arrange
      final serverTime = DateTime.utc(2026, 11, 2, 23); // 3 Nov 06.00
      final current = DateTime.utc(2026, 11, 3, 1); // 3 Nov 08.00

      // Act
      final result = AppDate.smart(serverTime, now: current);

      // Assert
      expect(result, '2 jam lalu');
    });

    test('uses Jakarta days when UTC days match but Jakarta days differ', () {
      // Arrange
      final serverTime = DateTime.utc(2026, 11, 3, 16); // 3 Nov 23.00
      final current = DateTime.utc(2026, 11, 3, 18); // 4 Nov 01.00

      // Act
      final result = AppDate.smart(serverTime, now: current);

      // Assert
      expect(result, 'Kemarin');
    });
  });
}
