import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/ownership_transfer.dart';
import '../../../domain/usecases/transfer_candidates_usecase.dart';
import '../../shared/controllers/members_controller.dart';
import '../controllers/transfer_offer_controller.dart';

/// Transfer ownership offer (S32), organizer only: "Serahkan pengurus ke
/// siapa?", what moves to the new organizer, a radio list of members with
/// an account, and "Kirim tawaran" behind a confirmation sheet. A sent
/// offer shows "Menunggu jawaban {name} · berlaku sampai {date}".
class const TransferOfferPage({super.key, required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = transferOfferControllerProvider(groupId);
    final myMemberId = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group?.myMemberId));
    final members = ref.watch(membersControllerProvider(groupId).select((s) => s.value ?? const <Member>[]));
    final candidates = ref.read(transferCandidatesUseCaseProvider)((members: members, myMemberId: myMemberId));
    final selectedId = ref.watch(provider.select((s) => s.selectedId));
    final sending = ref.watch(provider.select((s) => s.sending));
    final offered = ref.watch(provider.select((s) => s.offered));
    final margin = context.screenMargin;
    final selected = candidates.where((m) => m.id == selectedId).firstOrNull;

    Future<void> send() async {
      if (selected == null) return;
      final ok = await showConfirmationSheet(
        context,
        icon: AppIcons.crown,
        title: l10n.transferConfirmTitle(selected.displayName ?? ''),
        confirmLabel: l10n.transferSend,
        cancelLabel: l10n.commonCancel,
      );
      if (!ok || !context.mounted) return;
      final failure = await ref.read(provider.notifier).offer();
      if (!context.mounted || failure == null) return;
      showAppToast(
        context,
        failure.apiCode == ApiErrorCode.pendingRequestExists ? l10n.transferPendingExists : failure.displayMessage,
      );
    }

    return Scaffold(
      appBar: AppTopBar(),
      body: MaxWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s4),
              sliver: SliverList.list(
                children: [
                  HeadlineText(l10n.transferHeadline),
                  const SizedBox(height: AppSpace.s3),
                  Text(l10n.transferExplain, style: t.body.copyWith(color: c.textSecondary)),
                  if (offered != null) ...[
                    const SizedBox(height: AppSpace.s4),
                    _PendingCard(transfer: offered),
                  ],
                  if (candidates.isEmpty) ...[
                    const SizedBox(height: AppSpace.s4),
                    AppBanner(message: l10n.transferNoCandidates),
                  ],
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              sliver: SliverList.builder(
                itemCount: candidates.length,
                itemBuilder: (context, i) {
                  final m = candidates[i];
                  return _CandidateRow(
                    member: m,
                    selected: m.id == selectedId,
                    onTap: offered != null || m.id == null ? null : () => ref.read(provider.notifier).select(m.id!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: offered != null
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s4),
                child: AppButton(
                  label: l10n.transferSend,
                  block: true,
                  loading: sending,
                  onPressed: selected == null ? null : send,
                ),
              ),
            ),
    );
  }
}

class const _PendingCard({required final OwnershipTransfer transfer}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final expires = transfer.expiresAt;
    return AppBanner(
      icon: AppIcons.hourglassMedium,
      variant: AppBannerVariant.warning,
      message: l10n.transferPending(
        transfer.toMember?.displayName ?? '',
        expires == null ? '' : AppDate.full(AppDate.jakarta(expires)),
      ),
    );
  }
}

/// A radio row: avatar, name, slot and the selection mark.
class const _CandidateRow({required final Member member, required final bool selected, final VoidCallback? onTap})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final name = member.displayName ?? '';
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Pressable(
        onTap: onTap,
        shape: AppShapes.squircle(AppRadius.md),
        semanticLabel: name,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.rowH),
          child: Row(
            children: [
              AppAvatar(name: name, imageUrl: member.avatarUrl),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.title.copyWith(color: c.textPrimary)),
                    Text(
                      l10n.memberSlotCaption(CodeFormatter.slotNo(member.slotNo ?? 0)),
                      style: t.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              AppIcon(
                selected ? AppIcons.checkCircleFill : AppIcons.circle,
                size: 24,
                color: selected ? c.textPrimary : c.borderStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
