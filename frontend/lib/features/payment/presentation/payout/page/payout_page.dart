import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../../member/domain/entities/member.dart';
import '../../../domain/usecases/pick_payout_stage_usecase.dart';
import '../controllers/payout_controller.dart';
import '../controllers/payout_stage_provider.dart';

/// Payout (S40): the organizer records that the pot went to the winner
/// (optional proof and note); the winner confirms receipt, or taps "Belum
/// terima" for advice without telling the server anything; everyone else
/// sees whether it is waiting or confirmed. No doodles on this screen.
class const PayoutPage({
  super.key,
  required final String groupId,
  required final String periodId,
  required final VoidCallback onClose,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final margin = context.screenMargin;
    final stage = ref.watch(payoutStageProvider(groupId, periodId));
    final ids = (groupId: groupId, periodId: periodId);
    return Scaffold(
      appBar: AppTopBar(title: l10n.payoutTitle, onBack: onClose),
      body: MaxWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s8),
          children: [
            switch (stage) {
              PayoutStage.record => _RecordForm(ids: ids),
              PayoutStage.waiting => _Waiting(ids: ids),
              PayoutStage.confirm => _ConfirmReceipt(ids: ids),
              PayoutStage.confirmed => _Confirmed(ids: ids),
              PayoutStage.notRecorded => AppBanner(message: l10n.payoutNotRecorded),
            },
          ],
        ),
      ),
    );
  }
}

typedef _Ids = ({String groupId, String periodId});

/// The winner and the pot, from the payout once recorded, else the period
/// and the group.
typedef _Pot = ({MemberRef? winner, int amount});

_Pot _watchPot(WidgetRef ref, _Ids ids) {
  final payout = ref.watch(payoutControllerProvider(ids.groupId, ids.periodId).select((s) => s.payout));
  final detail = ref.watch(groupDetailControllerProvider(ids.groupId)).value;
  final period = detail?.periods.where((p) => p.id == ids.periodId).firstOrNull;
  final group = detail?.group;
  return (
    winner: payout?.winner ?? period?.winner,
    amount: payout?.amount ?? group?.potAmount ?? (group?.amount ?? 0) * (group?.totalSlots ?? 0),
  );
}

Future<void> _afterWrite(BuildContext context, WidgetRef ref, _Ids ids, Failure? failure, String success) async {
  final l10n = context.l10n;
  if (failure == null) {
    await HapticFeedback.mediumImpact();
    if (context.mounted) showAppToast(context, success);
    return;
  }
  if (failure.apiCode == ApiErrorCode.payoutAlreadyRecorded) {
    showAppToast(context, l10n.payoutAlreadyRecorded);
    await ref.read(payoutControllerProvider(ids.groupId, ids.periodId).notifier).refresh();
    return;
  }
  showAppToast(context, failure.displayMessage(context.l10n));
}

class const _RecordForm({required final _Ids ids}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = payoutControllerProvider(ids.groupId, ids.periodId);
    final notifier = ref.watch(provider.notifier);
    final state = ref.watch(provider);
    final online = ref.watch(connectivityControllerProvider.select((s) => s.value ?? true));
    final pot = _watchPot(ref, ids);
    final winner = pot.winner;

    Future<void> record() async {
      final failure = await notifier.record();
      if (context.mounted) await _afterWrite(context, ref, ids, failure, l10n.payoutRecorded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(l10n.payoutHeadline(Rupiah.format(pot.amount), winner?.displayName ?? '')),
        const SizedBox(height: AppSpace.s5),
        if (winner != null) _WinnerCard(winner: winner),
        const SizedBox(height: AppSpace.s3),
        Text(l10n.payoutCaption, style: t.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpace.s5),
        Text(l10n.payoutProofLabel, style: t.label.copyWith(color: c.textPrimary)),
        const SizedBox(height: AppSpace.s2),
        UploadTile(
          localPath: state.proofPath,
          onPick: state.busy ? null : notifier.pick,
          onRemove: state.busy ? null : notifier.removeProof,
        ),
        const SizedBox(height: AppSpace.s4),
        AppTextField(
          label: l10n.payoutNoteLabel,
          enabled: !state.busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          onChanged: notifier.setNote,
        ),
        const SizedBox(height: AppSpace.s4),
        CheckRow(
          label: l10n.payoutConsent,
          value: state.handedOver,
          onChanged: state.busy ? null : notifier.setHandedOver,
        ),
        const SizedBox(height: AppSpace.s5),
        AppButton(
          label: l10n.payoutRecordButton,
          loading: state.busy,
          disabledReason: online ? null : l10n.needsConnection,
          onPressed: state.canRecord && online ? record : null,
        ),
      ],
    );
  }
}

class const _WinnerCard({required final MemberRef winner}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return AppCard(
      child: Row(
        children: [
          AppAvatar(name: winner.displayName ?? '', imageUrl: winner.avatarUrl, guest: winner.isGuest ?? false),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(winner.displayName ?? '', style: t.title.copyWith(color: c.textPrimary)),
                Text(
                  l10n.memberSlotCaption(CodeFormatter.slotNo(winner.slotNo ?? 0)),
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recorded, waiting for the winner: the hatched status card.
class const _Waiting({required final _Ids ids}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final payout = ref.watch(payoutControllerProvider(ids.groupId, ids.periodId).select((s) => s.payout));
    final pot = _watchPot(ref, ids);
    final at = payout?.recordedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TikarHatch(
          color: c.pending.fg.withValues(alpha: 0.25),
          background: c.pending.bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.hourglassMedium, color: c.pending.fg),
                const SizedBox(height: AppSpace.s3),
                Text(
                  l10n.payoutWaiting(pot.winner?.displayName ?? ''),
                  style: t.title.copyWith(color: c.pending.fg),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(Rupiah.format(pot.amount), style: t.amount.copyWith(color: c.pending.fg)),
                if (at != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    l10n.payoutRecordedBy(
                      payout?.recordedBy?.name ?? '',
                      AppDate.smart(at, now: ref.watch(clockProvider)()),
                    ),
                    style: t.caption.copyWith(color: c.pending.fg),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (payout?.proofUrl case final url?) ...[const SizedBox(height: AppSpace.s4), _ProofThumb(url: url)],
      ],
    );
  }
}

/// The winner: "Sudah terima **Rp2.000.000**?".
class const _ConfirmReceipt({required final _Ids ids}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = payoutControllerProvider(ids.groupId, ids.periodId);
    final state = ref.watch(provider);
    final online = ref.watch(connectivityControllerProvider.select((s) => s.value ?? true));
    final pot = _watchPot(ref, ids);

    Future<void> confirm() async {
      final failure = await ref.read(provider.notifier).confirm();
      if (context.mounted) await _afterWrite(context, ref, ids, failure, l10n.payoutConfirmedToast);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineText(l10n.payoutWinnerHeadline(Rupiah.format(pot.amount))),
        if (state.payout?.proofUrl case final url?) ...[const SizedBox(height: AppSpace.s5), _ProofThumb(url: url)],
        const SizedBox(height: AppSpace.s6),
        AppButton(
          label: l10n.payoutConfirmButton,
          loading: state.busy,
          disabledReason: online ? null : l10n.needsConnection,
          onPressed: state.busy || !online ? null : confirm,
        ),
        const SizedBox(height: AppSpace.s3),
        AppButton.secondary(
          label: l10n.payoutNotYetButton,
          onPressed: () => showHelpSheet(
            context,
            title: l10n.payoutNotYetTitle,
            paragraphs: [l10n.payoutNotYetBody],
            dismissLabel: l10n.commonOk,
          ),
        ),
      ],
    );
  }
}

class const _Confirmed({required final _Ids ids}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final payout = ref.watch(payoutControllerProvider(ids.groupId, ids.periodId).select((s) => s.payout));
    final pot = _watchPot(ref, ids);
    final at = payout?.confirmedAt;
    final now = ref.watch(clockProvider)();
    final text = l10n.payoutConfirmed(pot.winner?.displayName ?? '', at == null ? '' : AppDate.smart(at, now: now));
    return AppCard(
      color: c.paid.bg,
      semanticLabel: text,
      child: Row(
        children: [
          AppIcon(AppIcons.checkCircleFill, color: c.paid.fg),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: t.title.copyWith(color: c.paid.fg)),
                Text(Rupiah.format(pot.amount), style: t.amount.copyWith(color: c.paid.fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _ProofThumb({required final String url}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      image: true,
      label: context.l10n.payoutProofSemantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          url,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => SizedBox(height: 160, child: ColoredBox(color: c.subtle)),
        ),
      ),
    );
  }
}
