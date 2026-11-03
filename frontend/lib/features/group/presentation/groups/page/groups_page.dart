import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/group_list_filter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/usecases/filter_groups_usecase.dart';
import '../controllers/groups_controller.dart';

/// The Grup tab (S11): my groups by segment (Aktif · Selesai), narrowed by
/// role chips, with the floating "Buat grup" pill while the list has groups.
class const GroupsPage({
  super.key,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
}) extends StatefulWidget {
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState() extends State<GroupsPage> {
  var _filter = GroupListFilter.active;

  @override
  Widget build(BuildContext context) {
    // S11 has no top bar: the headline is the screen's title.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _GroupsList(
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
          onOpenGroup: widget.onOpenGroup,
          onCreateGroup: widget.onCreateGroup,
        ),
      ),
    );
  }
}

class const _CreatePill({required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(shape: AppShapes.pill, shadows: AppElevation.float(context)),
      child: AppButton(
        label: context.l10n.createGroupButton,
        icon: AppIcons.plus,
        onPressed: onPressed,
      ),
    );
  }
}

class const _GroupsList({
  required final GroupListFilter filter,
  required final ValueChanged<GroupListFilter> onFilter,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = groupsControllerProvider(filter);
    final groups = ref.watch(provider.select((s) => s.value?.visibleGroups));
    final loaded = ref.watch(provider.select((s) => s.value?.loaded ?? false));
    final margin = context.screenMargin;
    final items = groups ?? const [];
    final showPill = items.isNotEmpty;
    // Inside the shell's extendBody, padding.bottom already covers the
    // floating nav bar, so this inset clears it.
    final navInset = AppBottomNavBar.contentInset(context);
    final listBottom = (context.isCompact ? navInset : AppSpace.s8) + (showPill ? AppSizes.buttonH + AppSpace.s6 : 0);

    Future<void> refresh() async {
      final failure = await ref.read(provider.notifier).refresh();
      if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
    }

    // The pill sits in a Stack, not the Scaffold's floatingActionButton: a
    // nested Scaffold places its FAB from viewPadding, which extendBody
    // doesn't grow, so it would land behind the shell's nav bar.
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: MaxWidth(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: margin),
                    child: _Header(filter: filter, onFilter: onFilter),
                  ),
                ),
              ),
              if (items.isEmpty && !loaded)
                SliverToBoxAdapter(child: _ListSkeleton(margin: margin))
              else if (items.isEmpty)
                // At least the space left under the header, so the empty
                // state centers there, but free to grow (and scroll) on short
                // screens. SliverFillRemaining sizes from intrinsics, which
                // undercount the doodle and overflow.
                SliverLayoutBuilder(
                  builder: (context, constraints) => SliverToBoxAdapter(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.viewportMainAxisExtent - constraints.precedingScrollExtent),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: listBottom),
                        child: _Empty(filter: filter, onCreateGroup: onCreateGroup),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: margin),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
                    itemBuilder: (context, i) => MaxWidth(
                      child: GroupCard(
                        group: items[i],
                        layout: GroupCardLayout.list,
                        onTap: () => onOpenGroup(items[i].id ?? ''),
                      ),
                    ),
                  ),
                ),
              if (items.isNotEmpty || !loaded) SliverPadding(padding: EdgeInsets.only(bottom: listBottom)),
            ],
          ),
        ),
        if (showPill)
          PositionedDirectional(
            end: margin,
            bottom: navInset,
            child: _CreatePill(onPressed: onCreateGroup),
          ),
      ],
    );
  }
}

class const _Header({
  required final GroupListFilter filter,
  required final ValueChanged<GroupListFilter> onFilter,
}) extends StatelessWidget {
  static const _segments = [GroupListFilter.active, GroupListFilter.finished];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        Semantics(header: true, child: HeadlineText(l10n.groupsHeadline)),
        const SizedBox(height: AppSpace.s5),
        SegmentedPills(
          segments: [l10n.groupsSegmentActive, l10n.groupsSegmentFinished],
          selectedIndex: _segments.indexOf(filter),
          onChanged: (i) => onFilter(_segments[i]),
        ),
        const SizedBox(height: AppSpace.s3),
        _RoleChips(filter: filter),
        const SizedBox(height: AppSpace.s4),
      ],
    );
  }
}

class const _RoleChips({required final GroupListFilter filter}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = groupsControllerProvider(filter);
    final chip = ref.watch(provider.select((s) => s.value?.chip ?? GroupChipFilter.all));
    void toggle(GroupChipFilter f) => ref.read(provider.notifier).toggleChip(f);
    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      children: [
        AppChip(
          label: l10n.filterManaging,
          selected: chip == GroupChipFilter.managing,
          onSelected: () => toggle(GroupChipFilter.managing),
        ),
        AppChip(
          label: l10n.filterMember,
          selected: chip == GroupChipFilter.member,
          onSelected: () => toggle(GroupChipFilter.member),
        ),
      ],
    );
  }
}

class const _Empty({required final GroupListFilter filter, required final VoidCallback onCreateGroup})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finished = filter == GroupListFilter.finished;
    return EmptyState(
      illustration: const Doodle(AppDoodles.rantang, size: 160),
      title: finished ? l10n.groupsEmptyFinished : l10n.groupsEmptyActive,
      message: finished ? l10n.groupsEmptyFinishedMessage : l10n.homeEmptyMessage,
      primaryLabel: finished ? null : l10n.createGroupButton,
      onPrimary: finished ? null : onCreateGroup,
    );
  }
}

class const _ListSkeleton({required final double margin}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: const Column(
        children: [
          Skeleton(height: 160, radius: AppRadius.lg),
          SizedBox(height: AppSpace.s3),
          Skeleton(height: 160, radius: AppRadius.lg),
        ],
      ),
    );
  }
}
