import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/leave_request.dart';
import '../../../domain/entities/member_input.dart';
import '../../../domain/entities/obligation.dart';
import '../controllers/leave_requests_controller.dart';

/// Leave requests review (S31): one card per pending request with the
/// member, slot, reason and date, a warning with the Obligation Meter for
/// past winners, and "Setujui" / "Tolak" (with an optional reason).
class const LeaveRequestsPage({super.key, required final String groupId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = leaveRequestsControllerProvider(groupId);
    final requests = ref.watch(provider.select((s) => s.value?.requests));
    final failure = ref.watch(provider.select((s) => s.hasValue ? null : s.error));
    return Scaffold(
      appBar: AppTopBar(title: l10n.leaveRequestsTitle),
      body: switch ((requests, failure)) {
        (final List<LeaveRequest> list, _) when list.isEmpty => EmptyState(
          illustration: const Doodle(AppDoodles.tikar, size: 160),
          title: l10n.leaveRequestsEmpty,
        ),
        (final List<LeaveRequest> list, _) => ListView.separated(
          padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s2, context.screenMargin, AppSpace.s8),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s4),
          itemBuilder: (context, i) => _RequestCard(groupId: groupId, request: list[i]),
        ),
        (null, final Failure f) => EmptyState(
          title: l10n.leaveRequestsTitle,
          message: f.displayMessage,
          primaryLabel: l10n.commonRetry,
          onPrimary: () => ref.invalidate(provider),
        ),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

class const _RequestCard({required final String groupId, required final LeaveRequest request}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = leaveRequestsControllerProvider(groupId);
    final id = request.id ?? '';
    final busy = ref.watch(provider.select((s) => s.value?.busyId == id));
    final obligation = ref.watch(provider.select((s) => s.value?.obligations[request.member?.id]));
    final total = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group?.totalSlots ?? 0));
    final member = request.member;
    final name = member?.displayName ?? '';
    final created = request.createdAt;

    Future<void> approve() async {
      final failure = await ref.read(provider.notifier).approve(id);
      if (context.mounted) showAppToast(context, failure?.displayMessage ?? l10n.leaveApproved(name));
    }

    Future<void> reject() async {
      final reason = await showAppSheet<String>(context, builder: (_) => _RejectSheet(name: name));
      if (reason == null || !context.mounted) return;
      final failure = await ref.read(provider.notifier).reject(id, reason);
      if (context.mounted) showAppToast(context, failure?.displayMessage ?? l10n.leaveRejected);
    }

    return AppCard(
      style: AppCardStyle.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: name, imageUrl: member?.avatarUrl, guest: member?.isGuest ?? false),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.title.copyWith(color: c.textPrimary)),
                    Text(
                      [
                        l10n.memberSlotCaption(CodeFormatter.slotNo(member?.slotNo ?? 0)),
                        if (created != null) l10n.leaveRequestedOn(AppDate.smart(created)),
                      ].join(' · '),
                      style: t.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          Text(
            (request.reason?.trim().isNotEmpty ?? false) ? request.reason! : l10n.leaveNoReason,
            style: t.body.copyWith(color: c.textSecondary),
          ),
          if (obligation != null) ...[
            const SizedBox(height: AppSpace.s3),
            AppBanner(message: l10n.leaveWinnerWarning, variant: AppBannerVariant.warning, compact: true),
            const SizedBox(height: AppSpace.s3),
            _Meter(name: name, obligation: obligation, totalSlots: total),
          ],
          const SizedBox(height: AppSpace.s4),
          Row(
            spacing: AppSpace.s3,
            children: [
              Expanded(
                child: AppButton.secondary(label: l10n.leaveReject, block: true, onPressed: busy ? null : reject),
              ),
              Expanded(
                child: AppButton(label: l10n.leaveApprove, block: true, loading: busy, onPressed: approve),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class const _Meter({required final String name, required final Obligation obligation, required final int totalSlots})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ObligationMeter(
    name: name,
    wonPeriodNo: obligation.wonPeriodNo ?? 0,
    periodsAfterWin: totalSlots - (obligation.wonPeriodNo ?? 0),
    remainingCount: obligation.remainingCount ?? 0,
    remainingAmount: obligation.remainingAmount ?? 0,
    overdueCount: obligation.overdueCount ?? 0,
    overdueAmount: obligation.overdueAmount ?? 0,
    showOverdue: true,
  );
}

/// The optional reject reason; pops the reason ('' for none).
class const _RejectSheet({required final String name}) extends StatefulWidget {
  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState() extends State<_RejectSheet> {
  final _reason = TextEditingController();
  var _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final errors = MemberRules.checkReason(_reason.text, minLength: MemberRules.minRejectReasonLength);
    if (errors.isNotEmpty) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(_reason.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheetBody(
      title: l10n.leaveRejectTitle(widget.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _reason,
            label: l10n.leaveRejectReason,
            labelHint: l10n.leaveReasonHint,
            maxLines: 3,
            autofocus: true,
            errorText: _invalid ? l10n.leaveRejectReasonError : null,
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
          ),
          const SizedBox(height: AppSpace.s6),
          AppButton.destructive(label: l10n.leaveRejectConfirm, block: true, onPressed: _confirm),
        ],
      ),
    );
  }
}
