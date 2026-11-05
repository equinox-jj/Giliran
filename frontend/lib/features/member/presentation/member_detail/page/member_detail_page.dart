import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/share_service.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/member_role.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/obligation.dart';
import '../../shared/widgets/claim_link_sheet.dart';
import '../../shared/widgets/guest_sheet.dart';
import '../controllers/member_detail_controller.dart';

/// Member detail: avatar, name and badges; slot, join date and win;
/// the Obligation Meter after a win; payment history (Phase 4); and, for
/// managers, WhatsApp reminder, claim link and guest edit (guests) and
/// "Keluarkan dari grup".
class const MemberDetailPage({
  super.key,
  required final String groupId,
  required final String memberId,
  required final VoidCallback onRemoved,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = memberDetailControllerProvider(groupId, memberId);
    final member = ref.watch(provider.select((s) => s.value?.member));
    final notFound = ref.watch(provider.select((s) => s.value?.notFound ?? false));
    return Scaffold(
      appBar: AppTopBar(),
      body: switch (member) {
        final Member m => _MemberDetailBody(groupId: groupId, member: m, onRemoved: onRemoved),
        null when notFound => EmptyState(
          illustration: const Doodle(AppDoodles.rantang, size: 160),
          title: l10n.memberNotFound,
        ),
        null => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

class const _MemberDetailBody({
  required final String groupId,
  required final Member member,
  required final VoidCallback onRemoved,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final group = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group));
    final obligation = ref.watch(
      memberDetailControllerProvider(groupId, member.id ?? '').select((s) => s.value?.obligation),
    );
    final manager = group?.isManager ?? false;
    final m = member;
    final guest = m.isGuest ?? false;
    final mine = m.id != null && m.id == group?.myMemberId;
    final joined = m.joinedAt;
    final phone = manager ? m.guestPhone : null;
    return MaxWidth(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
        children: [
          Center(
            child: AppAvatar(
              name: m.displayName ?? '',
              imageUrl: m.avatarUrl,
              size: 80,
              guest: guest,
              organizer: m.isManager,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Text(
            m.displayName ?? '',
            textAlign: TextAlign.center,
            style: t.titleLg.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s1,
            children: [
              if (m.isManager) LabelBadge(l10n.badgeOrganizer),
              if (guest) LabelBadge(l10n.badgeGuest),
              if (mine) LabelBadge(l10n.badgeYou),
            ],
          ),
          const SizedBox(height: AppSpace.s6),
          KeyValueList(
            items: [
              KeyValueItem(l10n.memberDetailSlot, CodeFormatter.slotNo(m.slotNo ?? 0), mono: true),
              if (joined != null) KeyValueItem(l10n.memberDetailJoined, AppDate.full(AppDate.jakarta(joined))),
              KeyValueItem(
                l10n.memberDetailWon,
                (m.hasWon ?? false) ? l10n.memberDetailWonValue(m.wonPeriodNo ?? 0) : l10n.memberDetailNotYet,
              ),
              if (phone != null) KeyValueItem(l10n.memberDetailPhone, PhoneFormatter.display(phone)),
            ],
          ),
          if (obligation != null && group != null) ...[
            const SizedBox(height: AppSpace.s6),
            _MeterFor(name: m.displayName ?? '', obligation: obligation, group: group, showOverdue: manager),
          ],
          SectionHeader(title: l10n.memberPaymentHistory, top: AppSpace.s6),
          Text(l10n.memberPaymentHistoryLater, style: t.body.copyWith(color: c.textSecondary)),
          if (manager && group != null) ...[
            const SizedBox(height: AppSpace.s8),
            _ManagerActions(group: group, member: m, onRemoved: onRemoved),
          ],
        ],
      ),
    );
  }
}

class const _MeterFor({
  required final String name,
  required final Obligation obligation,
  required final GroupDetail group,
  required final bool showOverdue,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final o = obligation;
    return ObligationMeter(
      name: name,
      wonPeriodNo: o.wonPeriodNo ?? 0,
      periodsAfterWin: (group.totalSlots ?? 0) - (o.wonPeriodNo ?? 0),
      remainingCount: o.remainingCount ?? 0,
      remainingAmount: o.remainingAmount ?? 0,
      overdueCount: o.overdueCount ?? 0,
      overdueAmount: o.overdueAmount ?? 0,
      showOverdue: showOverdue,
    );
  }
}

/// Organizer actions at the bottom of the page.
class const _ManagerActions({
  required final GroupDetail group,
  required final Member member,
  required final VoidCallback onRemoved,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groupId = group.id ?? '';
    final memberId = member.id ?? '';
    final provider = memberDetailControllerProvider(groupId, memberId);
    final busy = ref.watch(provider.select((s) => s.value?.busy ?? false));
    final guest = member.isGuest ?? false;
    final name = member.displayName ?? '';
    final removable = member.role != MemberRole.organizer;

    Future<void> remind() => ref
        .read(shareServiceProvider)
        .openWhatsApp(phone: member.guestPhone, text: l10n.memberRemindMessage(name, group.name ?? ''));

    Future<void> claimLink() async {
      final result = await ref.read(provider.notifier).createClaimLink();
      if (!context.mounted) return;
      switch (result) {
        case Right(:final value):
          await showClaimLinkSheet(context, guest: member, link: value, groupName: group.name ?? '');
        case Left(:final value):
          showAppToast(context, value.displayMessage(context.l10n));
      }
    }

    Future<void> editGuest() async {
      final saved = await showGuestSheet(context, groupId: groupId, guest: member);
      if (saved != null && context.mounted) showAppToast(context, l10n.guestSaved);
    }

    Future<void> remove() async {
      final ok = await showAppDialog(
        context,
        title: l10n.memberRemoveTitle(name),
        message: l10n.memberRemoveMessage,
        confirmLabel: l10n.memberRemove,
        cancelLabel: l10n.commonCancel,
      );
      if (!ok || !context.mounted) return;
      final failure = await ref.read(provider.notifier).remove();
      if (!context.mounted) return;
      if (failure == null) {
        showAppToast(context, l10n.memberRemoved(name));
        onRemoved();
      } else if (failure.apiCode == ApiErrorCode.obligationsOutstanding) {
        final count = ref.read(provider).value?.obligation?.remainingCount ?? 0;
        await showAppDialog(
          context,
          title: l10n.memberRemoveBlockedTitle,
          message: l10n.memberRemoveBlocked(name, count),
          confirmLabel: l10n.commonOk,
          destructive: false,
          showCancel: false,
        );
      } else {
        showAppToast(context, failure.displayMessage(context.l10n));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s3,
      children: [
        if (!guest || member.guestPhone != null)
          AppButton.secondary(
            label: l10n.memberRemindWhatsApp,
            icon: AppIcons.whatsappLogo,
            block: true,
            onPressed: remind,
          ),
        if (guest) ...[
          AppButton.secondary(
            label: l10n.memberCreateClaimLink,
            icon: AppIcons.linkSimple,
            block: true,
            loading: busy,
            onPressed: claimLink,
          ),
          AppButton.secondary(label: l10n.memberEditGuest, icon: AppIcons.user, block: true, onPressed: editGuest),
        ],
        if (removable) AppButton.destructive(label: l10n.memberRemove, block: true, onPressed: busy ? null : remove),
      ],
    );
  }
}
