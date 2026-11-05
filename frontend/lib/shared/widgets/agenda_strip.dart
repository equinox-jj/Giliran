import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/date_formatter.dart';
import '../../features/home/domain/entities/agenda_day.dart';
import 'app_icon.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// The Home week strip (Tikar §9.9): seven days, each a weekday label over a
/// 40 px token showing that day's most important event. Today is kunyit
/// with an ink outline; empty days are dashed. Tapping a day selects it so
/// the screen can list its events.
class const AgendaStrip({
  super.key,
  required final List<AgendaDay> days,
  final int? selectedIndex,
  required final ValueChanged<int> onSelect,
}) extends StatelessWidget {
  /// The width seven days need to keep a 48 dp tap target each.
  static const minWidth = 7 * AppSizes.tapMin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < days.length; i++)
          // Flexible keeps seven days from overflowing a row narrower than
          // [minWidth]; give the strip at least that width (Home lets it use
          // part of the page margin) so the targets stay 48 dp.
          Flexible(
            child: _AgendaDayToken(
              day: days[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class const _AgendaDayToken({
  required final AgendaDay day,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  static const _token = 40.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final weekday = DateFormat('EEE', 'id_ID').format(day.date);
    final events = day.events.isEmpty
        ? l10n.agendaNothing
        : [
            for (final e in day.events)
              switch (e.kind) {
                AgendaEventKind.due => l10n.agendaDue(e.groupName),
                AgendaEventKind.draw => l10n.agendaDraw(e.groupName),
                AgendaEventKind.payout => l10n.agendaPayout(e.groupName),
              },
          ].join(', ');
    final date = AppDate.short(day.date, now: day.date);
    final label = l10n.agendaDaySemantics(day.isToday ? '${l10n.agendaToday}, $date' : date, events);

    return Pressable(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      semanticLabel: label,
      selected: selected,
      child: ExcludeSemantics(
        child: SizedBox(
          width: AppSizes.tapMin,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                style: t.micro.copyWith(color: day.isToday ? c.textPrimary : c.textSecondary),
              ),
              const SizedBox(height: AppSpace.s1),
              SizedBox.square(
                dimension: _token,
                child: _TokenFace(day: day, selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _TokenFace({required final AgendaDay day, required final bool selected}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final kind = day.topKind;
    final icon = switch (kind) {
      AgendaEventKind.due => AppIcons.receipt,
      AgendaEventKind.draw => AppIcons.shuffle,
      AgendaEventKind.payout => AppIcons.handCoins,
      null => null,
    };
    final fg = day.isToday ? c.ink : c.textPrimary;
    final Widget content = icon == null
        ? Text(
            '${day.date.day}',
            style: t.caption.copyWith(color: day.isToday ? c.ink : c.textTertiary),
          )
        : AppIcon(icon, size: AppSizes.iconMd, color: fg);

    if (day.isToday) {
      return DecoratedBox(
        decoration: ShapeDecoration(
          color: c.turn,
          shape: CircleBorder(
            side: BorderSide(color: c.ink, width: AppStroke.ink),
          ),
        ),
        child: Center(child: content),
      );
    }
    if (kind == null) {
      return DashedBorder.circle(
        color: selected ? c.textPrimary : c.borderStrong,
        child: Center(child: content),
      );
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.surface,
        shape: CircleBorder(
          side: BorderSide(color: selected ? c.textPrimary : c.hairline, width: AppStroke.regular),
        ),
      ),
      child: Center(child: content),
    );
  }
}
