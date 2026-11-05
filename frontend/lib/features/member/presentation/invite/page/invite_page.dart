import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/share_service.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/usecases/next_free_slot_usecase.dart';
import '../../shared/controllers/members_controller.dart';
import '../../shared/widgets/guest_sheet.dart';
import '../controllers/invite_controller.dart';

/// Invite (S16): "Undang {n} orang lagi", the QR and code, WhatsApp share
/// and copy, the slot list, and "Tambah tamu". Managers can make a new link
/// from the menu; old links stop working.
class const InvitePage({super.key, required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groupProvider = groupDetailControllerProvider(groupId);
    final membersProvider = membersControllerProvider(groupId);
    final manager = ref.watch(groupProvider.select((s) => s.value?.group?.isManager ?? false));

    Future<void> refresh() async {
      final results = await Future.wait([
        ref.read(groupProvider.notifier).refresh(),
        ref.read(membersProvider.notifier).refresh(),
      ]);
      final failure = results.nonNulls.firstOrNull;
      if (failure != null && context.mounted) showAppToast(context, failure.displayMessage(context.l10n));
    }

    Future<void> reset() async {
      final ok = await showConfirmationSheet(
        context,
        icon: AppIcons.linkSimple,
        title: l10n.inviteResetTitle,
        confirmLabel: l10n.inviteResetMenu,
        cancelLabel: l10n.commonCancel,
      );
      if (!ok || !context.mounted) return;
      final failure = await ref.read(inviteControllerProvider(groupId).notifier).resetCode();
      if (context.mounted) showAppToast(context, failure?.displayMessage(context.l10n) ?? l10n.inviteResetDone);
    }

    final hero = _InviteHero(groupId: groupId);
    final slots = _SlotsSection(groupId: groupId);
    return Scaffold(
      appBar: AppTopBar(
        actions: [
          if (manager)
            OverflowMenuButton(
              items: [OverflowMenuItem(label: l10n.inviteResetMenu, icon: AppIcons.linkSimple, onSelected: reset)],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: context.isCompact
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, 0),
                    sliver: SliverToBoxAdapter(child: hero),
                  ),
                  slots,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.gutter / 2, AppSpace.s8),
                      children: [hero],
                    ),
                  ),
                  Expanded(child: CustomScrollView(slivers: [slots])),
                ],
              ),
      ),
    );
  }
}

/// Headline, the QR hero and the share buttons.
class const _InviteHero({required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final group = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group));
    if (group == null) return const Center(child: CircularProgressIndicator.adaptive());
    final remaining = (group.totalSlots ?? 0) - (group.filledSlots ?? 0);
    final full = remaining <= 0;
    final invite = group.invite;
    final url = invite?.url;

    Future<void> shareWhatsApp() async {
      if (url == null) return;
      await ref.read(shareServiceProvider).openWhatsApp(text: l10n.inviteShareMessage(group.name ?? '', url));
    }

    Future<void> copyLink() async {
      if (url == null) return;
      await Clipboard.setData(ClipboardData(text: url));
      await HapticFeedback.lightImpact();
      if (context.mounted) showAppToast(context, l10n.inviteLinkCopied);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(full ? l10n.inviteFullHeadline : l10n.inviteHeadline(remaining)),
        const SizedBox(height: AppSpace.s6),
        if (invite == null || url == null)
          AppBanner(message: l10n.inviteNoLink)
        else
          _QrPanel(group: group, invite: invite, full: full),
        const SizedBox(height: AppSpace.s4),
        if (full)
          AppButton.secondary(
            label: l10n.inviteShareWhatsApp,
            icon: AppIcons.whatsappLogo,
            block: true,
            onPressed: url == null ? null : shareWhatsApp,
          )
        else
          AppButton(
            label: l10n.inviteShareWhatsApp,
            icon: AppIcons.whatsappLogo,
            block: true,
            onPressed: url == null ? null : shareWhatsApp,
          ),
        const SizedBox(height: AppSpace.s3),
        AppButton.secondary(
          label: l10n.inviteCopyLink,
          icon: AppIcons.linkSimple,
          block: true,
          onPressed: url == null ? null : copyLink,
        ),
      ],
    );
  }
}

/// Tone hero with the QR (ink on a cream square) and the grouped code.
class const _QrPanel({required final GroupDetail group, required final Invite invite, required final bool full})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final tone = c.tones[group.toneIndex % c.tones.length];
    final code = invite.code ?? '';

    Future<void> copyCode() async {
      await Clipboard.setData(ClipboardData(text: code));
      await HapticFeedback.lightImpact();
      if (context.mounted) showAppToast(context, l10n.inviteCodeCopied);
    }

    return HeroPanel(
      color: tone.surface,
      child: Column(
        children: [
          if (full) ...[
            Text(l10n.inviteFull, style: t.title.copyWith(color: c.textPrimary)),
            const SizedBox(height: AppSpace.s4),
          ],
          Semantics(
            label: l10n.inviteQrSemantics(group.name ?? ''),
            image: true,
            child: Container(
              padding: const EdgeInsets.all(AppSpace.s3),
              decoration: ShapeDecoration(color: c.ticketBody, shape: AppShapes.squircle(AppRadius.lg)),
              child: QrImageView(
                key: ValueKey('qr:${invite.url}'),
                data: invite.url ?? '',
                size: 200,
                padding: EdgeInsets.zero,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.ink),
                dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: c.ink),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(l10n.inviteCodeLabel, style: t.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.s1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(CodeFormatter.grouped(code), style: t.mono.copyWith(color: c.textPrimary, fontSize: 20)),
              const SizedBox(width: AppSpace.s2),
              CircleIconButton(icon: AppIcons.copy, semanticLabel: l10n.inviteCopyCodeSemantics, onPressed: copyCode),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Slot": one row per slot (member or dashed empty), then "Tambah tamu".
class const _SlotsSection({required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group?.totalSlots ?? 0));
    final manager = ref.watch(
      groupDetailControllerProvider(groupId).select((s) => s.value?.group?.isManager ?? false),
    );
    final members = ref.watch(membersControllerProvider(groupId).select((s) => s.value ?? const <Member>[]));
    final bySlot = {for (final m in members) m.slotNo: m};
    final nextSlot = ref.read(nextFreeSlotUseCaseProvider)((members: members, totalSlots: total));
    final margin = context.screenMargin;

    Future<void> addGuest() async {
      final added = await showGuestSheet(context, groupId: groupId, slotNo: nextSlot);
      if (added != null && context.mounted) {
        showAppToast(context, l10n.guestAdded(added.displayName ?? '', CodeFormatter.slotNo(added.slotNo ?? 0)));
      }
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(margin, 0, margin, AppSpace.s8),
      sliver: SliverList.builder(
        itemCount: total + 2,
        itemBuilder: (context, i) {
          if (i == 0) return SectionHeader(title: l10n.inviteSlotsSection, top: AppSpace.s6);
          if (i == total + 1) {
            return manager
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s4),
                    child: AppButton.ghost(
                      label: l10n.inviteAddGuest,
                      icon: AppIcons.userPlus,
                      onPressed: nextSlot == null ? null : addGuest,
                    ),
                  )
                : const SizedBox.shrink();
          }
          return _SlotRow(slotNo: i, member: bySlot[i]);
        },
      ),
    );
  }
}

class const _SlotRow({required final int slotNo, required final Member? member}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final m = member;
    final number = CodeFormatter.slotNo(slotNo);
    return AppListRow(
      title: m?.displayName ?? l10n.inviteEmptySlot,
      leading: m == null
          ? SizedBox.square(
              dimension: AppSizes.avatarMd,
              child: CustomPaint(
                painter: DashedBorderPainter(color: c.borderStrong, circle: true),
                child: Center(
                  child: Text(number, style: t.caption.copyWith(color: c.textTertiary)),
                ),
              ),
            )
          : AppAvatar(name: m.displayName ?? '', imageUrl: m.avatarUrl, guest: m.isGuest ?? false),
      trailing: Text(number, style: t.mono.copyWith(color: c.textSecondary)),
    );
  }
}
