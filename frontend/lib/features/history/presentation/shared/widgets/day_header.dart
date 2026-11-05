import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/date_formatter.dart';

/// "Hari ini", "Kemarin" or "Sab, 18 Okt" above the first item of a Jakarta
/// day, in the Aktivitas lists. [day] is a Jakarta business date
/// at UTC midnight.
class const DayHeader({
  super.key,
  required final DateTime day,
  required final DateTime now,
  final EdgeInsetsGeometry padding = const EdgeInsets.only(top: AppSpace.s4, bottom: AppSpace.s1),
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = AppDate.jakartaToday(now);
    final label = switch (today.difference(day).inDays) {
      0 => l10n.activityToday,
      1 => l10n.activityYesterday,
      _ => AppDate.short(day, now: today),
    };
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(label, style: AppTextStyles.of(context).label.copyWith(color: context.colors.textSecondary)),
      ),
    );
  }
}
