import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../../payment/domain/entities/period.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../activity_tab/widgets/activity_tab.dart';
import '../../schedule_tab/widgets/schedule_tab.dart';
import '../controllers/cycle_summary_controller.dart';

/// What "Buat arisan baru" carries into Create group.
typedef NewCyclePrefill = ({int? amount, PeriodType? periodType, int? totalSlots});

/// The tabs a finished group keeps, read-only.
enum _SummaryTab() {
  schedule,
  activity,
}

/// Group summary of a completed or closed group: the Cycle Summary
/// card, "Buat arisan baru" (organizer, prefilled from this group) or
/// "Lihat riwayat" (members), then the Jadwal and Aktivitas tabs read-only
/// under an "Arisan sudah selesai" banner.
class const GroupSummaryPage({
  super.key,
  required final String groupId,
  required final ValueChanged<NewCyclePrefill> onCreateNew,
  required final ValueChanged<String> onBuktiKocok,
}) extends StatefulWidget {
  @override
  State<GroupSummaryPage> createState() => _GroupSummaryPageState();
}

class _GroupSummaryPageState() extends State<GroupSummaryPage> {
  var _tab = _SummaryTab.schedule;

  /// The tab switch, scrolled to by "Lihat riwayat".
  final _tabsKey = GlobalKey();

  void _viewHistory() {
    setState(() => _tab = _SummaryTab.activity);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabs = _tabsKey.currentContext;
      if (tabs == null || !tabs.mounted) return;
      Scrollable.ensureVisible(
        tabs,
        duration: AppMotion.reduced(tabs) ? Duration.zero : AppMotion.base,
        curve: AppMotion.baseCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: context.l10n.summaryTitle),
      body: _Body(
        groupId: widget.groupId,
        tab: _tab,
        tabsKey: _tabsKey,
        onTab: (t) => setState(() => _tab = t),
        onViewHistory: _viewHistory,
        onCreateNew: widget.onCreateNew,
        onBuktiKocok: widget.onBuktiKocok,
      ),
    );
  }
}

class const _Body({
  required final String groupId,
  required final _SummaryTab tab,
  required final GlobalKey tabsKey,
  required final ValueChanged<_SummaryTab> onTab,
  required final VoidCallback onViewHistory,
  required final ValueChanged<NewCyclePrefill> onCreateNew,
  required final ValueChanged<String> onBuktiKocok,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = groupDetailControllerProvider(groupId);
    final group = ref.watch(provider.select((s) => s.value?.group));
    final periods = ref.watch(provider.select((s) => s.value?.periods ?? const <Period>[]));
    final margin = context.screenMargin;
    if (group == null) return const Center(child: Skeleton(height: 200));

    Future<void> refresh() async {
      final failure = await ref.read(provider.notifier).refresh();
      if (failure != null && context.mounted) showAppToast(context, failure.displayMessage(context.l10n));
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, 0),
            sliver: SliverToBoxAdapter(
              child: MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(group: group, onBuktiKocok: onBuktiKocok),
                    const SizedBox(height: AppSpace.s5),
                    if (group.isManager)
                      AppButton(
                        label: l10n.summaryCreateNew,
                        onPressed: () => onCreateNew((
                          amount: group.amount,
                          periodType: group.periodType,
                          totalSlots: group.totalSlots,
                        )),
                      )
                    else
                      AppButton.secondary(
                        label: l10n.summaryViewHistory,
                        onPressed: onViewHistory,
                      ),
                    const SizedBox(height: AppSpace.s6),
                    AppBanner(
                      message: group.status == GroupStatus.closed
                          ? l10n.summaryClosedBanner
                          : l10n.summaryFinishedBanner,
                      compact: true,
                    ),
                    const SizedBox(height: AppSpace.s4),
                    SegmentedPills(
                      key: tabsKey,
                      segments: [l10n.tabSchedule, l10n.tabActivity],
                      selectedIndex: tab.index,
                      onChanged: (i) => onTab(_SummaryTab.values[i]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s4, margin, AppSpace.s8),
            sliver: switch (tab) {
              _SummaryTab.schedule => ScheduleTab(group: group, periods: periods, onBuktiKocok: onBuktiKocok),
              _SummaryTab.activity => ActivityTab(groupId: groupId),
            },
          ),
        ],
      ),
    );
  }
}

class const _SummaryCard({required final GroupDetail group, required final ValueChanged<String> onBuktiKocok})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final summary = ref.watch(cycleSummaryProvider(group.id ?? ''));
    if (summary == null) return const SizedBox.shrink();
    final now = AppDate.jakarta(ref.watch(clockProvider)());
    final ended = summary.endedAt;
    return CycleSummaryCard(
      tone: c.tones[group.toneIndex % c.tones.length],
      headline: summary.closedEarly
          ? l10n.summaryHeadlineClosed(ended == null ? '' : AppDate.short(AppDate.jakarta(ended), now: now))
          : l10n.summaryHeadlineCompleted(summary.periodCount, summary.winnerCount),
      subline: summary.closedEarly ? l10n.summaryClosedDrawn(summary.winners.length, summary.periodCount) : null,
      stats: [
        CycleStat(value: Rupiah.format(summary.totalCollected), label: l10n.summaryStatCollected),
        CycleStat(
          value: summary.paidPercent == null ? '–' : l10n.summaryPercent(summary.paidPercent!),
          label: l10n.summaryStatPaidRate,
        ),
        CycleStat(value: '${summary.memberCount}', label: l10n.summaryStatMembers),
      ],
      tokens: _tokens(summary, group.myMemberId),
      winners: [
        for (final w in summary.winners)
          CycleWinnerRow(
            periodId: w.periodId,
            title: w.winner?.displayName == null
                ? l10n.scheduleBarPeriod(w.periodNo)
                : l10n.summaryWinnerRow(w.periodNo, w.winner!.displayName!),
            date: w.drawnAt == null ? null : AppDate.short(AppDate.jakarta(w.drawnAt!), now: now),
          ),
      ],
      onProof: onBuktiKocok,
    );
  }

  /// Every period: drawn ones with their winner, the rest dashed.
  static List<PeriodTokenData> _tokens(CycleSummary summary, String? myMemberId) {
    final byNo = {for (final w in summary.winners) w.periodNo: w};
    return [
      for (var n = 1; n <= summary.periodCount; n++)
        if (byNo[n] case final w?)
          PeriodTokenData(
            id: w.periodId,
            periodNo: n,
            state: SlotTokenState.done,
            winnerName: w.winner?.displayName,
            winnerAvatarUrl: w.winner?.avatarUrl,
            iWon: myMemberId != null && w.winner?.id == myMemberId,
          )
        else
          PeriodTokenData(id: 'p$n', periodNo: n, state: SlotTokenState.upcoming),
    ];
  }
}
