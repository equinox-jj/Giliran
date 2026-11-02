import 'package:intl/intl.dart';

/// Indonesian date and time display. Call `initializeDateFormatting('id_ID')`
/// at startup before using these.
abstract final class AppDate {
  static const _locale = 'id_ID';

  /// "Sab, 1 Nov 2026" (date fields).
  static String full(DateTime d) => DateFormat('EEE, d MMM y', _locale).format(d);

  /// "Sab, 25 Okt" this year, "25 Okt 2025" other years.
  static String short(DateTime d, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return d.year == today.year
        ? DateFormat('EEE, d MMM', _locale).format(d)
        : DateFormat('d MMM y', _locale).format(d);
  }

  /// 24-hour time with a dot: "19.30".
  static String time(DateTime d) => DateFormat('HH.mm', _locale).format(d);
}
