import 'package:intl/intl.dart';

/// Indonesian date and time display. Call `initializeDateFormatting('id_ID')`
/// at startup before using these.
abstract final class AppDate() {
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

  /// The Asia/Jakarta (WIB, UTC+7, no DST) wall-clock time of [d], for display
  /// of API timestamps. The result is flagged UTC; read only its fields.
  static DateTime jakarta(DateTime d) => d.toUtc().add(const Duration(hours: 7));

  /// Today's Asia/Jakarta business date at UTC midnight, the form business
  /// dates (`due_date`, `draw_date`) are parsed into.
  static DateTime jakartaToday(DateTime now) {
    final j = jakarta(now);
    return DateTime.utc(j.year, j.month, j.day);
  }

  /// Relative within 48 hours ("Baru saja", "2 jam lalu", "Kemarin", "Besok",
  /// "15 menit lagi"), otherwise [short], judged on Jakarta calendar days.
  ///
  /// Takes real instants (API UTC timestamps or local times) and converts
  /// [d] and [now] to Jakarta itself. Don't pass a [jakarta] result: it is
  /// already shifted and would be shifted again.
  static String smart(DateTime d, {DateTime? now}) {
    final at = jakarta(d);
    final ref = jakarta(now ?? DateTime.now());
    final diff = at.difference(ref);
    if (diff.abs() >= const Duration(hours: 48)) return short(at, now: ref);

    final dayOffset = _dayOnly(at).difference(_dayOnly(ref)).inDays;
    final past = diff.isNegative;
    final span = diff.abs();
    if (dayOffset == 0) {
      if (span < const Duration(minutes: 1)) return 'Baru saja';
      final amount = span < const Duration(hours: 1) ? '${span.inMinutes} menit' : '${span.inHours} jam';
      return past ? '$amount lalu' : '$amount lagi';
    }
    if (dayOffset == -1) return 'Kemarin';
    if (dayOffset == 1) return 'Besok';
    return short(at, now: ref);
  }

  // Calendar day at UTC midnight, so the day count ignores DST and zone flags.
  static DateTime _dayOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}
