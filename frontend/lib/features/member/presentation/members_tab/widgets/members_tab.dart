import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/obligation.dart';
import '../../../domain/usecases/next_free_slot_usecase.dart';
import '../../shared/controllers/members_controller.dart';
import '../../shared/widgets/guest_sheet.dart';
import '../controllers/members_tab_controller.dart';

/// The Anggota tab (S22) as slivers inside the group detail scroll view:
/// organizer buttons (Undang, Tambah tamu), pending leave requests or the
/// member's own pending banner, Obligation Meters for past winners (overdue
/// first, hidden while nobody has won), then every member by slot.
class const MembersTab({
  super.key,
  required final GroupDetail group,
  required final VoidCallback onInvite,
  required final ValueChanged<String> onOpenMember,
  required final VoidCallback onLeaveRequests,
  required final VoidCallback onLeave,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = group.id ?? '';
    final members = ref.watch(membersControllerProvider(groupId).select((s) => s.value ?? const <Member>[]));
    final tab = ref.watch(membersTabControllerProvider(groupId));
    final obligations = tab.value?.obligations ?? const <Obligation>[];
    final manager = group.isManager;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _TabHeader(
            group: group,
            members: members,
            pendingLeaveCount: tab.value?.pendingLeaveCount ?? 0,
            failed: tab.hasError && !tab.isLoading,
            onInvite: onInvite,
            onLeaveRequests: onLeaveRequests,
            onRetry: () => ref.read(membersTabControllerProvider(groupId).notifier).refresh(),
          ),
        ),
        if (obligations.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(title: context.l10n.obligationsSection, top: AppSpace.s6),
          ),
          SliverList.separated(
            itemCount: obligations.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s4),
            itemBuilder: (context, i) {
              final o = obligations[i];
              return ObligationMeter(
                name: o.member?.displayName ?? '',
                wonPeriodNo: o.wonPeriodNo ?? 0,
                periodsAfterWin: (group.totalSlots ?? 0) - (o.wonPeriodNo ?? 0),
                remainingCount: o.remainingCount ?? 0,
                remainingAmount: o.remainingAmount ?? 0,
                overdueCount: o.overdueCount ?? 0,
                overdueAmount: o.overdueAmount ?? 0,
                showOverdue: manager,
              );
            },
          ),
        ],
        SliverToBoxAdapter(
          child: SectionHeader(title: context.l10n.membersSection(members.length), top: AppSpace.s6),
        ),
        SliverList.builder(
          itemCount: members.length,
          itemBuilder: (context, i) {
            final m = members[i];
            final mine = m.id != null && m.id == group.myMemberId;
            return MemberRow(
              member: m,
              mine: mine,
              showPhone: manager,
              onTap: m.id == null ? null : () => onOpenMember(m.id!),
              onLeave: mine ? onLeave : null,
            );
          },
        ),
      ],
    );
  }
}

class const _TabHeader({
  required final GroupDetail group,
  required final List<Member> members,
  required final int pendingLeaveCount,
  required final bool failed,
  required final VoidCallback onInvite,
  required final VoidCallback onLeaveRequests,
  required final VoidCallback onRetry,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final manager = group.isManager;
    final nextSlot = ref.read(nextFreeSlotUseCaseProvider)((members: members, totalSlots: group.totalSlots ?? 0));

    Future<void> addGuest() async {
      final added = await showGuestSheet(context, groupId: group.id ?? '', slotNo: nextSlot);
      if (added != null && context.mounted) {
        showAppToast(context, l10n.guestAdded(added.displayName ?? '', CodeFormatter.slotNo(added.slotNo ?? 0)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (manager)
          Row(
            spacing: AppSpace.s3,
            children: [
              Expanded(
                child: AppButton(label: l10n.membersInvite, icon: AppIcons.userPlus, block: true, onPressed: onInvite),
              ),
              Expanded(
                child: AppButton.secondary(
                  label: l10n.membersAddGuest,
                  icon: AppIcons.user,
                  block: true,
                  onPressed: nextSlot == null ? null : addGuest,
                ),
              ),
            ],
          ),
        if (manager && pendingLeaveCount > 0) ...[
          const SizedBox(height: AppSpace.s4),
          AppCard(
            style: AppCardStyle.outlined,
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: l10n.membersLeaveRequests(pendingLeaveCount),
              leading: const AppIcon(AppIcons.signOut),
              trailing: const AppIcon(AppIcons.arrowRight, size: 20),
              onTap: onLeaveRequests,
            ),
          ),
        ],
        if (!manager && pendingLeaveCount > 0) ...[
          const SizedBox(height: AppSpace.s4),
          AppBanner(message: l10n.leavePendingBanner, variant: AppBannerVariant.warning),
        ],
        if (failed) ...[
          const SizedBox(height: AppSpace.s4),
          AppBanner(
            message: l10n.homeLoadErrorMessage,
            variant: AppBannerVariant.error,
            actionLabel: l10n.commonRetry,
            onAction: onRetry,
          ),
        ],
      ],
    );
  }
}

/// One member: avatar, name with badges (Pengurus, Tamu, Kamu), the slot
/// (and, for managers, a guest's phone), and the "Sudah dapat P{n}" chip.
/// [onLeave] puts "Minta keluar" on the viewer's own row.
class const MemberRow({
  super.key,
  required final Member member,
  final bool mine = false,
  final bool showPhone = false,
  final VoidCallback? onTap,
  final VoidCallback? onLeave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final m = member;
    final guest = m.isGuest ?? false;
    final won = m.hasWon ?? false;
    final phone = showPhone ? m.guestPhone : null;
    final slot = l10n.memberSlotCaption(CodeFormatter.slotNo(m.slotNo ?? 0));
    final caption = phone == null ? slot : '$slot · ${PhoneFormatter.display(phone)}';
    final label = [
      m.displayName ?? '',
      caption,
      if (m.isManager) l10n.badgeOrganizer,
      if (guest) l10n.badgeGuest,
      if (mine) l10n.badgeYou,
      if (won) l10n.memberWonChip(m.wonPeriodNo ?? 0),
    ].join(', ');
    return Pressable(
      onTap: onTap,
      shape: AppShapes.squircle(AppRadius.md),
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.rowH),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
          child: Row(
            children: [
              ExcludeSemantics(
                child: AppAvatar(
                  name: m.displayName ?? '',
                  imageUrl: m.avatarUrl,
                  guest: guest,
                  organizer: m.isManager,
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: AppSpace.s1,
                        runSpacing: AppSpace.s1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(m.displayName ?? '', style: t.title.copyWith(color: c.textPrimary)),
                          if (m.isManager) LabelBadge(l10n.badgeOrganizer),
                          if (guest) LabelBadge(l10n.badgeGuest),
                          if (mine) LabelBadge(l10n.badgeYou),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(caption, style: t.caption.copyWith(color: c.textSecondary)),
                      if (won) ...[
                        const SizedBox(height: AppSpace.s1),
                        StatusChip(ChipStatus.won, label: l10n.memberWonChip(m.wonPeriodNo ?? 0)),
                      ],
                    ],
                  ),
                ),
              ),
              if (onLeave != null)
                OverflowMenuButton(
                  semanticLabel: l10n.menuLeave,
                  items: [OverflowMenuItem(label: l10n.menuLeave, icon: AppIcons.signOut, onSelected: onLeave!)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
