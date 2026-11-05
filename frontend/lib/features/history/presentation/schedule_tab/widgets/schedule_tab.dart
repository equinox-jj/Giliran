import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../../payment/domain/entities/period.dart';
import '../../../domain/entities/schedule.dart';
import '../controllers/schedule_controller.dart';

/// The Jadwal tab as a sliver inside the group detail scroll view:
/// the "Periode · Bulan" switch, the Jadwal timeline with today's line,
/// then one row per period with its winner (or "Belum dikocok") and a
/// "Bukti" link to the Bukti Kocok of drawn periods.
class const ScheduleTab({
  super.key,
  required final GroupDetail group,
  required final List<Period> periods,
  required final ValueChanged<String> onBuktiKocok,
}) extends StatefulWidget {
  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState() extends State<ScheduleTab> {
  ScheduleScale _scale = ScheduleScale.period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.periods.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          compact: true,
          illustration: const Doodle(AppDoodles.kalender, size: 120),
          title: l10n.tabSchedule,
          message: l10n.scheduleEmpty,
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SegmentedPills(
            segments: [l10n.scheduleScalePeriod, l10n.scheduleScaleMonth],
            selectedIndex: _scale.index,
            onChanged: (i) => setState(() => _scale = ScheduleScale.values[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s4)),
        SliverToBoxAdapter(
          child: _Timeline(periods: widget.periods, scale: _scale),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s4)),
        _PeriodList(periods: widget.periods, myMemberId: widget.group.myMemberId, onBuktiKocok: widget.onBuktiKocok),
      ],
    );
  }
}

class const _Timeline({required final List<Period> periods, required final ScheduleScale scale})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final schedule = ref.watch(scheduleProvider(periods, scale));
    return Semantics(
      label: l10n.scheduleCompletionSemantics(schedule.completionPercent),
      child: JadwalTimeline(
        todayAt: schedule.todayAt,
        todayLabel: l10n.scheduleCompletion(schedule.completionPercent),
        ticks: [for (final t in schedule.ticks) JadwalTick(at: t.at, label: AppDate.month(t.month))],
        bars: [
          for (final bar in schedule.bars)
            JadwalBar(
              periodNo: bar.periodNo,
              start: bar.start,
              end: bar.end,
              fill: switch (bar.state) {
                ScheduleBarState.drawn => JadwalBarFill.drawn,
                ScheduleBarState.open => JadwalBarFill.open,
                ScheduleBarState.upcoming => JadwalBarFill.upcoming,
              },
              tone: bar.winnerId == null ? null : c.toneFor(bar.winnerId!).accent,
              label: bar.winnerName == null
                  ? l10n.scheduleBarPeriod(bar.periodNo)
                  : l10n.scheduleBarWinner(bar.periodNo, bar.winnerName!),
              semanticsLabel: switch (bar.state) {
                ScheduleBarState.drawn when bar.winnerName != null => l10n.slotTokenDoneWinner(
                  bar.periodNo,
                  bar.winnerName!,
                ),
                ScheduleBarState.drawn => l10n.slotTokenDone(bar.periodNo),
                ScheduleBarState.open => l10n.slotTokenCurrent(bar.periodNo),
                ScheduleBarState.upcoming => l10n.slotTokenUpcoming(bar.periodNo),
              },
            ),
        ],
      ),
    );
  }
}

/// The periods under the timeline: one column on phones, two on wide
/// screens.
class const _PeriodList({
  required final List<Period> periods,
  required final String? myMemberId,
  required final ValueChanged<String> onBuktiKocok,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sorted = [...periods]..sort((a, b) => (a.periodNo ?? 0).compareTo(b.periodNo ?? 0));
    if (context.sizeClass == SizeClass.expanded) {
      return SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: AppSizes.rowH,
          crossAxisSpacing: AppSpace.s4,
        ),
        itemCount: sorted.length,
        itemBuilder: (context, i) => _PeriodRow(period: sorted[i], myMemberId: myMemberId, onBuktiKocok: onBuktiKocok),
      );
    }
    return SliverList.builder(
      itemCount: sorted.length,
      itemBuilder: (context, i) => _PeriodRow(period: sorted[i], myMemberId: myMemberId, onBuktiKocok: onBuktiKocok),
    );
  }
}

class const _PeriodRow({
  required final Period period,
  required final String? myMemberId,
  required final ValueChanged<String> onBuktiKocok,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final now = ref.watch(clockProvider)();
    final no = period.periodNo ?? 0;
    final winner = period.winner;
    final drawn = period.isDrawn;
    final draw = period.drawDate;
    final date = draw == null ? null : AppDate.short(draw, now: now);
    final title = winner?.displayName == null
        ? (drawn ? l10n.scheduleBarPeriod(no) : l10n.scheduleNotDrawn)
        : l10n.scheduleBarWinner(no, winner!.displayName!);
    final subtitle = date == null ? null : (drawn ? l10n.scheduleDrawnOn(date) : l10n.scheduleDrawOn(date));
    return SizedBox(
      key: ValueKey('schedule-row-${period.id}'),
      height: AppSizes.rowH,
      child: Row(
        children: [
          SlotToken(
            periodNo: no,
            state: drawn
                ? SlotTokenState.done
                : period.isUpcoming
                ? SlotTokenState.upcoming
                : SlotTokenState.current,
            winnerName: winner?.displayName,
            winnerAvatarUrl: winner?.avatarUrl,
            iWon: myMemberId != null && winner?.id == myMemberId,
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.label.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: t.caption.copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (drawn && period.id != null)
            Semantics(
              label: l10n.scheduleProofSemantics(no),
              button: true,
              excludeSemantics: true,
              child: AppTextButton(label: l10n.scheduleProofLink, onPressed: () => onBuktiKocok(period.id!)),
            ),
        ],
      ),
    );
  }
}
