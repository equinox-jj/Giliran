import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/member_role.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../domain/entities/member_input.dart';
import '../../../domain/entities/obligation.dart';
import '../controllers/leave_controller.dart';

/// Opens Leave request for [group]. [obligation] is the caller's own,
/// when known, so a past winner who still owes sees why up front.
/// [onTransfer] opens Transfer ownership from the organizer's blocked
/// state. Resolves to true when the request was sent.
Future<bool> showLeaveRequestSheet(
  BuildContext context, {
  required GroupDetail group,
  Obligation? obligation,
  required VoidCallback onTransfer,
}) async =>
    await showAppSheet<bool>(
      context,
      builder: (_) => LeaveRequestSheet(group: group, obligation: obligation, onTransfer: onTransfer),
    ) ??
    false;

/// "Minta keluar dari grup": explanation, an optional reason (500) and a
/// destructive "Kirim permintaan". The organizer (`organizer_cannot_leave`)
/// gets a link to Transfer ownership instead; a past winner with dues
/// (`obligations_outstanding`) sees them on the Obligation Meter.
class const LeaveRequestSheet({
  super.key,
  required final GroupDetail group,
  final Obligation? obligation,
  required final VoidCallback onTransfer,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState() extends ConsumerState<LeaveRequestSheet> {
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(_onReasonChanged);
  }

  @override
  void dispose() {
    _reason
      ..removeListener(_onReasonChanged)
      ..dispose();
    super.dispose();
  }

  void _onReasonChanged() => setState(() {});

  String get _groupId => widget.group.id ?? '';

  Future<void> _send() async {
    final l10n = context.l10n;
    final sent = await ref.read(leaveControllerProvider(_groupId).notifier).send(_reason.text);
    if (!mounted) return;
    if (sent) {
      showAppToast(context, l10n.leaveSent);
      Navigator.of(context).pop(true);
      return;
    }
    final failure = ref.read(leaveControllerProvider(_groupId)).failure;
    switch (failure?.apiCode) {
      case ApiErrorCode.pendingRequestExists:
        showAppToast(context, l10n.leavePendingExists);
        Navigator.of(context).pop(false);
      case ApiErrorCode.organizerCannotLeave || ApiErrorCode.obligationsOutstanding || ApiErrorCode.validationError:
        break;
      case _:
        if (failure != null) showAppToast(context, failure.displayMessage(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final state = ref.watch(leaveControllerProvider(_groupId));
    final code = state.failure?.apiCode;
    final owed = widget.obligation;
    final organizer = widget.group.myRole == MemberRole.organizer || code == ApiErrorCode.organizerCannotLeave;
    final owes = (owed?.remainingCount ?? 0) > 0 || code == ApiErrorCode.obligationsOutstanding;
    final length = _reason.text.trim().length;
    final tooLong = length > MemberRules.maxReasonLength || state.failure is ValidationFailure;

    return AppSheetBody(
      title: l10n.leaveSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (organizer) ...[
            AppBanner(message: l10n.leaveOrganizerBlocked, variant: AppBannerVariant.warning),
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: l10n.leaveTransferLink,
              block: true,
              onPressed: () {
                Navigator.of(context).pop(false);
                widget.onTransfer();
              },
            ),
          ] else if (owes) ...[
            AppBanner(
              message: l10n.leaveObligationsBlocked(owed?.remainingCount ?? 0),
              variant: AppBannerVariant.warning,
            ),
            if (owed != null) ...[
              const SizedBox(height: AppSpace.s4),
              ObligationMeter(
                name: owed.member?.displayName ?? '',
                wonPeriodNo: owed.wonPeriodNo ?? 0,
                periodsAfterWin: (widget.group.totalSlots ?? 0) - (owed.wonPeriodNo ?? 0),
                remainingCount: owed.remainingCount ?? 0,
                remainingAmount: owed.remainingAmount ?? 0,
                overdueCount: owed.overdueCount ?? 0,
                overdueAmount: owed.overdueAmount ?? 0,
                showOverdue: true,
              ),
            ],
          ] else ...[
            Text(l10n.leaveSheetHelp, style: t.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.s4),
            AppTextField(
              controller: _reason,
              label: l10n.leaveReasonLabel,
              labelHint: l10n.leaveReasonHint,
              maxLines: 3,
              counter: l10n.leaveReasonCounter(length),
              errorText: tooLong ? l10n.leaveReasonTooLong : null,
            ),
            const SizedBox(height: AppSpace.s6),
            AppButton.destructive(
              label: l10n.leaveSend,
              block: true,
              loading: state.sending,
              onPressed: length > MemberRules.maxReasonLength ? null : _send,
            ),
          ],
        ],
      ),
    );
  }
}
