import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../auth/domain/entities/auth_status.dart';
import '../../../../auth/presentation/shared/controllers/auth_session_controller.dart';
import '../../../../group/domain/usecases/filter_groups_usecase.dart';
import '../../../../profile/domain/entity/profile.dart';
import '../../../domain/entities/agenda_day.dart';
import '../controllers/home_controller.dart';
import '../widgets/group_carousel.dart';
import '../widgets/home_headline.dart';
import '../widgets/next_action_hero.dart';

/// Beranda (S10): what needs me now across all my groups. Shows the cache
/// at once and refreshes in the background; pull to refresh.
class const HomePage({
  super.key,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
  required final VoidCallback onJoinByLink,
  final VoidCallback? onAvatar,
  final VoidCallback? onBell,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _HomeTopBar(onAvatar: onAvatar, onBell: onBell),
      body: _HomeBody(
        onOpenGroup: onOpenGroup,
        onCreateGroup: onCreateGroup,
        onJoinByLink: onJoinByLink,
      ),
    );
  }
}

ProfileData? _sessionUser(AsyncValue<AuthStatus> status) => switch (status.value) {
  AuthUnlocked(:final user) || AuthLocked(:final user) => user,
  _ => null,
};

String _firstName(String? name) => (name ?? '').trim().split(RegExp(r'\s+')).first;

class const _HomeTopBar({final VoidCallback? onAvatar, final VoidCallback? onBell})
    extends ConsumerWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.greetingBarH);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionControllerProvider.select(_sessionUser));
    final count = ref.watch(homeControllerProvider.select((s) => s.value?.groups.length ?? 0));
    return GreetingTopBar(
      name: _firstName(user?.name),
      avatarUrl: user?.avatarUrl,
      subtitle: count == 0 ? null : context.l10n.homeActiveCount(count),
      onAvatar: onAvatar,
      onBell: onBell,
    );
  }
}

enum _Phase() {
  loading,
  empty,
  content,
  error,
}

_Phase _phaseOf(AsyncValue<HomeState> value) {
  final state = value.value;
  if (state == null) return value.hasError ? _Phase.error : _Phase.loading;
  if (state.groups.isNotEmpty) return _Phase.content;
  return state.loaded ? _Phase.empty : _Phase.loading;
}

class const _HomeBody({
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
  required final VoidCallback onJoinByLink,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(homeControllerProvider.select(_phaseOf));
    final bottom = context.isCompact ? AppBottomNavBar.contentInset(context) : AppSpace.s8;

    Future<void> refresh() async {
      final failure = await ref.read(homeControllerProvider.notifier).refresh();
      if (failure != null && context.mounted) showAppToast(context, failure.displayMessage(context.l10n));
    }

    final slivers = switch (phase) {
      _Phase.loading => const [SliverToBoxAdapter(child: _HomeSkeleton())],
      _Phase.error => [
        SliverToBoxAdapter(
          child: _HomeError(onRetry: refresh),
        ),
      ],
      _Phase.empty => [
        const SliverToBoxAdapter(child: _OfflineNotice()),
        const SliverToBoxAdapter(child: _HeadlineSection()),
        SliverToBoxAdapter(
          child: EmptyState(
            illustration: const Doodle(AppDoodles.rantang, size: 200),
            title: context.l10n.homeEmptyTitle,
            message: context.l10n.homeEmptyMessage,
            primaryLabel: context.l10n.createGroupButton,
            onPrimary: onCreateGroup,
            secondaryLabel: context.l10n.joinByLinkButton,
            onSecondary: onJoinByLink,
          ),
        ),
      ],
      _Phase.content => switch (context.sizeClass) {
        SizeClass.compact => _compactSlivers(onOpenGroup, onCreateGroup, onJoinByLink),
        _ => _wideSlivers(context, onOpenGroup, onCreateGroup, onJoinByLink),
      },
    };

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...slivers,
          SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
        ],
      ),
    );
  }

  static List<Widget> _compactSlivers(
    ValueChanged<String> onOpenGroup,
    VoidCallback onCreateGroup,
    VoidCallback onJoinByLink,
  ) => [
    const SliverToBoxAdapter(child: _OfflineNotice()),
    const SliverToBoxAdapter(child: _HeadlineSection()),
    SliverToBoxAdapter(
      child: _Margins(child: _HeroSection(onOpenGroup: onOpenGroup)),
    ),
    const SliverToBoxAdapter(child: _AgendaSection(ownMargins: true)),
    const SliverToBoxAdapter(child: _Margins(child: _GroupsHeader())),
    SliverToBoxAdapter(
      child: _CarouselSection(
        onOpenGroup: onOpenGroup,
        onCreateGroup: onCreateGroup,
        onJoinByLink: onJoinByLink,
      ),
    ),
  ];

  /// Medium: hero and agenda side by side over a 2-column grid. Expanded:
  /// the same with a 3-column grid (Tikar S10 tablet).
  static List<Widget> _wideSlivers(
    BuildContext context,
    ValueChanged<String> onOpenGroup,
    VoidCallback onCreateGroup,
    VoidCallback onJoinByLink,
  ) {
    final columns = context.sizeClass == SizeClass.expanded ? 3 : 2;
    return [
      const SliverToBoxAdapter(child: _OfflineNotice()),
      const SliverToBoxAdapter(child: _HeadlineSection()),
      SliverToBoxAdapter(
        child: _Margins(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HeroSection(onOpenGroup: onOpenGroup)),
              SizedBox(width: context.gutter),
              const Expanded(child: _AgendaSection()),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: _Margins(child: _GroupsHeader())),
      _GroupGrid(
        columns: columns,
        onOpenGroup: onOpenGroup,
        onCreateGroup: onCreateGroup,
        onJoinByLink: onJoinByLink,
      ),
    ];
  }
}

class const _Margins({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.screenMargin),
    child: child,
  );
}

class const _OfflineNotice() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityControllerProvider.select((s) => s.value ?? true));
    if (online) return const SizedBox.shrink();
    final synced = ref.watch(homeControllerProvider.select((s) => s.value?.lastSyncedAt));
    return _Margins(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s2),
        child: OfflineBanner(lastSyncedAt: synced),
      ),
    );
  }
}

class const _HeadlineSection() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authSessionControllerProvider.select((s) => _sessionUser(s)?.name));
    final counts = ref.watch(
      homeControllerProvider.select((s) => (s.value?.groups.length ?? 0, s.value?.openDues ?? 0)),
    );
    return _Margins(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: HomeHeadline(firstName: _firstName(name), groupCount: counts.$1, openDues: counts.$2),
      ),
    );
  }
}

class const _HeroSection({required final ValueChanged<String> onOpenGroup}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(homeControllerProvider.select((s) => s.value?.nextAction));
    return NextActionHero(action: action, onOpenGroup: onOpenGroup);
  }
}

/// The agenda strip and, under it, the selected day's events. With
/// [ownMargins] (phone layout) it pads itself, and on narrow phones the strip
/// takes part of the page margin so each day keeps a 48 dp tap target.
class const _AgendaSection({final bool ownMargins = false}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AgendaSection> createState() => _AgendaSectionState();
}

class _AgendaSectionState() extends ConsumerState<_AgendaSection> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(homeControllerProvider.select((s) => s.value?.agenda ?? const <AgendaDay>[]));
    final selected = _selected;
    final margin = widget.ownMargins ? context.screenMargin : 0.0;
    final spare = (MediaQuery.sizeOf(context).width - AgendaStrip.minWidth) / 2;
    final stripMargin = widget.ownMargins ? math.min(margin, math.max(0.0, spare)) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: stripMargin),
            child: AgendaStrip(
              days: days,
              selectedIndex: selected,
              onSelect: (i) => setState(() => _selected = i == _selected ? null : i),
            ),
          ),
          if (selected != null && selected < days.length)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: _DayEvents(day: days[selected]),
            ),
        ],
      ),
    );
  }
}

class const _DayEvents({required final AgendaDay day}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final style = t.body.copyWith(color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day.events.isEmpty) Text(l10n.agendaNothing, style: style),
          // A day holds at most a few events (one or two per group).
          for (final e in day.events)
            Text(
              switch (e.kind) {
                AgendaEventKind.due => l10n.agendaDue(e.groupName),
                AgendaEventKind.draw => l10n.agendaDraw(e.groupName),
                AgendaEventKind.payout => l10n.agendaPayout(e.groupName),
              },
              style: style,
            ),
        ],
      ),
    );
  }
}

class const _GroupsHeader() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(homeControllerProvider.select((s) => s.value?.filter ?? GroupChipFilter.all));
    void select(GroupChipFilter f) => ref.read(homeControllerProvider.notifier).setFilter(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.homeSectionGroups),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (f, label) in [
                (GroupChipFilter.all, l10n.filterAll),
                (GroupChipFilter.managing, l10n.filterManaging),
                (GroupChipFilter.unpaid, l10n.filterUnpaid),
              ]) ...[
                AppChip(label: label, selected: filter == f, onSelected: () => select(f)),
                const SizedBox(width: AppSpace.s2),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s3),
      ],
    );
  }
}

class const _CarouselSection({
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
  required final VoidCallback onJoinByLink,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(homeControllerProvider.select((s) => s.value?.visibleGroups ?? const []));
    final filtered = ref.watch(homeControllerProvider.select((s) => s.value?.filter != GroupChipFilter.all));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.isEmpty && filtered) const _FilterEmpty(),
        GroupCarousel(
          groups: groups,
          onOpenGroup: onOpenGroup,
          onCreateGroup: onCreateGroup,
          onJoinByLink: onJoinByLink,
        ),
      ],
    );
  }
}

class const _FilterEmpty() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return _Margins(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s3),
        child: Text(context.l10n.filterEmpty, style: t.body.copyWith(color: c.textSecondary)),
      ),
    );
  }
}

/// Tablet grid of Group Cards (aspect 1 : 0.85) ending with the dashed card.
class const _GroupGrid({
  required final int columns,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
  required final VoidCallback onJoinByLink,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(homeControllerProvider.select((s) => s.value?.visibleGroups ?? const []));
    final gutter = context.gutter;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.screenMargin),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: gutter,
          crossAxisSpacing: gutter,
          childAspectRatio: 1 / 0.85,
        ),
        itemCount: groups.length + 1,
        itemBuilder: (context, i) {
          if (i == groups.length) {
            return CreateOrJoinCard(onCreateGroup: onCreateGroup, onJoinByLink: onJoinByLink, fill: true);
          }
          final group = groups[i];
          return GroupCard(
            group: group,
            layout: GroupCardLayout.grid,
            onTap: () => onOpenGroup(group.id ?? ''),
          );
        },
      ),
    );
  }
}

class const _HomeSkeleton() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Margins(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.s4),
          const Skeleton.line(width: 240, height: 28),
          const SizedBox(height: AppSpace.s4),
          const Skeleton(height: AppSizes.heroMinH, radius: AppRadius.xl),
          const SizedBox(height: AppSpace.s6),
          SizedBox(
            height: GroupCard.carouselHeight,
            child: Row(
              children: [
                const SizedBox(
                  width: GroupCard.carouselWidth,
                  child: Skeleton(height: GroupCard.carouselHeight, radius: AppRadius.lg),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: const Skeleton(height: GroupCard.carouselHeight, radius: AppRadius.lg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _HomeError({required final Future<void> Function() onRetry}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      title: l10n.homeLoadErrorTitle,
      message: l10n.homeLoadErrorMessage,
      primaryLabel: l10n.commonRetry,
      onPrimary: onRetry,
    );
  }
}
