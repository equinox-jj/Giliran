import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/activity_copy.dart';
import '../../shared/widgets/day_header.dart';
import '../controllers/activity_tab_controller.dart';

/// The Aktivitas tab (S23) as a sliver inside the group detail scroll
/// view: the append-only notice, activity rows grouped by Jakarta day and
/// an end row that loads older pages (cursor pagination, 30 per page)
/// until "Ini awal riwayat grup.".
class const ActivityTab({super.key, required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = activityTabControllerProvider(groupId);
    final state = ref.watch(provider).value ?? const ActivityTabState();
    final entries = state.entries;
    final c = context.colors;

    final intro = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s2),
        child: Text(l10n.activityIntro, style: AppTextStyles.of(context).caption.copyWith(color: c.textSecondary)),
      ),
    );
    if (entries.isEmpty && !state.loaded) {
      return SliverMainAxisGroup(
        slivers: [
          intro,
          const SliverToBoxAdapter(child: _Skeleton()),
        ],
      );
    }
    if (entries.isEmpty && !state.hasMore) {
      return SliverMainAxisGroup(
        slivers: [
          intro,
          SliverToBoxAdapter(
            child: EmptyState(
              compact: true,
              illustration: const Doodle(AppDoodles.kalender, size: 120),
              title: l10n.tabActivity,
              message: l10n.activityEmpty,
            ),
          ),
        ],
      );
    }
    final now = ref.watch(clockProvider)();
    return SliverMainAxisGroup(
      slivers: [
        intro,
        SliverList.builder(
          itemCount: entries.length + 1,
          itemBuilder: (context, i) {
            if (i == entries.length) {
              return _EndRow(
                // A new cursor gives a new row, which asks for that page even
                // when the old row was already on screen.
                key: ValueKey(state.nextCursor),
                hasMore: state.hasMore,
                failed: state.failure != null && !state.loadingMore,
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRetry: () => ref.read(provider.notifier).retryMore(),
              );
            }
            final item = entries[i];
            final at = item.entry.createdAt;
            final previous = i == 0 ? null : entries[i - 1].entry.createdAt;
            final day = at == null ? null : AppDate.jakartaToday(at);
            final showHeader = day != null && (previous == null || AppDate.jakartaToday(previous) != day);
            return _EntryItem(item: item, header: showHeader ? day : null, now: now);
          },
        ),
      ],
    );
  }
}

class const _EntryItem({required final ActivityItem item, required final DateTime? header, required final DateTime now})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = item.description;
    final at = item.entry.createdAt;
    final day = header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (day != null) DayHeader(day: day, now: now),
        ActivityRow(
          icon: d.icon,
          title: d.sentence(l10n),
          time: at == null ? '' : AppDate.time(AppDate.jakarta(at)),
          diffs: d.diffLines(l10n, now: AppDate.jakarta(now)),
          system: d.isSystem,
        ),
      ],
    );
  }
}

class const _EndRow({
  super.key,
  required final bool hasMore,
  required final bool failed,
  required final VoidCallback onLoadMore,
  required final VoidCallback onRetry,
}) extends StatefulWidget {
  @override
  State<_EndRow> createState() => _EndRowState();
}

class _EndRowState() extends State<_EndRow> {
  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(_EndRow old) {
    super.didUpdateWidget(old);
    if (widget.hasMore && !old.hasMore) _maybeLoad();
  }

  void _maybeLoad() {
    if (!widget.hasMore || widget.failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    if (!widget.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
        child: Text(
          l10n.activityEnd,
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: c.textTertiary),
        ),
      );
    }
    if (widget.failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Column(
          children: [
            Text(l10n.activityLoadMoreFailed, style: t.caption.copyWith(color: c.textSecondary)),
            AppTextButton(label: l10n.commonRetry, onPressed: widget.onRetry),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: _SkeletonRow(),
    );
  }
}

class const _Skeleton() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Column(
    children: [_SkeletonRow(), _SkeletonRow(), _SkeletonRow()],
  );
}

class const _SkeletonRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpace.s2),
    child: Row(
      children: [
        Skeleton.circle(size: ActivityRow.leadingSize),
        SizedBox(width: AppSpace.s3),
        Expanded(child: Skeleton.line()),
      ],
    ),
  );
}
