import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/payment_status.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/payment.dart';
import '../controllers/proof_review_controller.dart';
import '../widgets/reject_reason_sheet.dart';

/// Proof review (S35) for managers, or the payer's own proof viewer: the
/// image viewer on top and a panel with the payer, the expected amount,
/// the upload time and period. Managers approve (after a confirmation
/// sheet) or reject (with a reason) a pending proof, and swipe between the
/// period's pending proofs ("1 dari 3 menunggu").
class const ProofReviewPage({
  super.key,
  required final String groupId,
  required final String paymentId,
  required final VoidCallback onClose,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<ProofReviewPage> createState() => _ProofReviewPageState();
}

class _ProofReviewPageState() extends ConsumerState<ProofReviewPage> {
  ProofReviewControllerProvider get _provider => proofReviewControllerProvider(widget.groupId, widget.paymentId);

  var _queueLoaded = false;

  @override
  void initState() {
    super.initState();
    // The group (and so my role) may arrive after the first frame; load the
    // pending queue once it says I'm a manager.
    ref.listenManual(
      groupDetailControllerProvider(widget.groupId).select((s) => s.value?.group?.isManager ?? false),
      (_, manager) {
        if (!manager || _queueLoaded) return;
        _queueLoaded = true;
        ref.read(_provider.notifier).loadQueue();
      },
      fireImmediately: true,
    );
  }

  int? _periodNo(Payment? payment) {
    final periods = ref.read(groupDetailControllerProvider(widget.groupId)).value?.periods ?? const [];
    return periods.where((p) => p.id == payment?.periodId).firstOrNull?.periodNo;
  }

  Future<void> _approve() async {
    final l10n = context.l10n;
    final payment = ref.read(_provider).current;
    if (payment == null) return;
    final name = payment.member?.displayName ?? '';
    final confirmed = await showConfirmationSheet(
      context,
      icon: AppIcons.checkCircle,
      title: l10n.proofApproveTitle(name),
      confirmLabel: l10n.proofApprove,
      cancelLabel: l10n.commonCancel,
      summary: [
        KeyValueItem(l10n.proofExpected, Rupiah.format(payment.amount ?? 0)),
        KeyValueItem(l10n.proofPeriod, '${_periodNo(payment) ?? ''}'),
      ],
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(_provider.notifier).approve();
    await _afterReview(failure, l10n.proofApproved);
  }

  Future<void> _reject() async {
    final l10n = context.l10n;
    final payment = ref.read(_provider).current;
    if (payment == null) return;
    final name = payment.member?.displayName ?? '';
    final reason = await showRejectReasonSheet(context, name: name);
    if (reason == null || !mounted) return;
    final failure = await ref.read(_provider.notifier).reject(reason);
    await _afterReview(failure, l10n.proofRejected(name));
  }

  Future<void> _afterReview(Failure? failure, String success) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final notifier = ref.read(_provider.notifier);
    if (failure == null) {
      showAppToast(context, success);
      if (!notifier.advance()) widget.onClose();
      return;
    }
    if (failure.apiCode == ApiErrorCode.paymentAlreadyReviewed || failure.apiCode == ApiErrorCode.invalidPaymentState) {
      showAppToast(context, l10n.proofAlreadyReviewed);
      await notifier.reload();
      return;
    }
    showAppToast(context, failure.displayMessage(context.l10n));
  }

  void _swipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    final state = ref.read(_provider);
    final next = state.index + (v < 0 ? 1 : -1);
    if (next >= 0 && next < state.queue.length) ref.read(_provider.notifier).select(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final manager = ref.watch(
      groupDetailControllerProvider(widget.groupId).select((s) => s.value?.group?.isManager ?? false),
    );
    final viewer = _Viewer(
      provider: _provider,
      title: manager ? l10n.proofReviewTitle : l10n.proofViewerTitle,
      onClose: widget.onClose,
    );
    final panel = _Panel(
      provider: _provider,
      manager: manager,
      periodNo: _periodNo,
      onApprove: _approve,
      onReject: _reject,
    );
    return Scaffold(
      backgroundColor: c.viewerBg,
      body: GestureDetector(
        onHorizontalDragEnd: manager ? _swipe : null,
        child: context.sizeClass == SizeClass.compact
            ? Column(
                children: [
                  Expanded(flex: 65, child: viewer),
                  Expanded(flex: 35, child: panel),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 7, child: viewer),
                  Expanded(flex: 5, child: panel),
                ],
              ),
      ),
    );
  }
}

class const _Viewer({
  required final ProofReviewControllerProvider provider,
  required final String title,
  required final VoidCallback onClose,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final payment = ref.watch(provider.select((s) => s.current));
    final failure = ref.watch(provider.select((s) => s.loadFailure));
    final proofs = payment?.proofs ?? [?payment?.currentProof];
    final pages = [
      for (final p in proofs)
        if (p.url case final url?)
          ImageViewerPage(
            url: url,
            uploaderName: payment?.member?.displayName ?? title,
            caption: p.uploadedAt == null
                ? null
                : '${AppDate.smart(p.uploadedAt!)}, ${AppDate.time(AppDate.jakarta(p.uploadedAt!))}',
          ),
    ];
    if (payment == null && failure == null) {
      return const Center(child: CircularProgressIndicator(color: AppPalette.cream));
    }
    return ImageViewer(
      key: ValueKey(payment?.id),
      pages: pages,
      onClose: onClose,
      emptyText: failure != null ? l10n.proofLoadFailed : l10n.proofNone,
    );
  }
}

class const _Panel({
  required final ProofReviewControllerProvider provider,
  required final bool manager,
  required final int? Function(Payment?) periodNo,
  required final VoidCallback onApprove,
  required final VoidCallback onReject,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final state = ref.watch(provider);
    final online = ref.watch(connectivityControllerProvider.select((s) => s.value ?? true));
    final payment = state.current;
    final member = payment?.member;
    final status = payment?.status ?? PaymentStatus.unpaid;
    final uploaded = payment?.uploadedAt;
    final reviewable = manager && state.canReview;
    final offlineReason = online ? null : l10n.needsConnection;
    return Container(
      decoration: ShapeDecoration(color: c.surfaceRaised, shape: AppShapes.squircleTop(AppRadius.xl)),
      padding: EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s5,
        AppSpace.s5,
        AppSpace.s5 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: member?.displayName ?? '',
                  imageUrl: member?.avatarUrl,
                  guest: member?.isGuest ?? false,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member?.displayName ?? '', style: t.title.copyWith(color: c.textPrimary)),
                      Text(
                        l10n.memberSlotCaption(CodeFormatter.slotNo(member?.slotNo ?? 0)),
                        style: t.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                StatusChip(ChipStatus.fromPayment(status)),
              ],
            ),
            if (manager && state.queue.length > 1) ...[
              const SizedBox(height: AppSpace.s3),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.proofReviewCounter(state.index + 1, state.queue.length),
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s4),
            KeyValueList(
              items: [
                KeyValueItem(l10n.proofExpected, Rupiah.format(payment?.amount ?? 0)),
                if (uploaded != null)
                  KeyValueItem(
                    l10n.proofUploadedAt,
                    '${AppDate.smart(uploaded)} ${AppDate.time(AppDate.jakarta(uploaded))}',
                  ),
                if (periodNo(payment) case final n?) KeyValueItem(l10n.proofPeriod, '$n'),
                if (payment?.rejectReason case final reason? when status == PaymentStatus.rejected)
                  KeyValueItem(l10n.proofStatus, reason, long: true),
              ],
            ),
            if (manager && status == PaymentStatus.pendingReview) ...[
              const SizedBox(height: AppSpace.s5),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.proofReject,
                      variant: AppButtonVariant.secondary,
                      disabledReason: offlineReason,
                      onPressed: reviewable && online ? onReject : null,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: AppButton(
                      label: l10n.proofApprove,
                      loading: state.busy,
                      disabledReason: offlineReason,
                      onPressed: reviewable && online ? onApprove : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
