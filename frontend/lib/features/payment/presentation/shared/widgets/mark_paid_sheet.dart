import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/payment_method.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/mark_paid_usecase.dart';
import '../controllers/mark_paid_controller.dart';

/// Opens Mark paid (S36) for [payment]. Resolves to the saved payment
/// (`pendingSync` when it was queued offline), or null when cancelled.
Future<Payment?> showMarkPaidSheet(
  BuildContext context, {
  required String groupId,
  required Payment payment,
}) => showAppSheet<Payment>(
  context,
  builder: (context) => _MarkPaidSheet(groupId: groupId, payment: payment),
);

class const _MarkPaidSheet({required final String groupId, required final Payment payment})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState() extends ConsumerState<_MarkPaidSheet> {
  final _note = TextEditingController();

  MarkPaidControllerProvider get _provider => markPaidControllerProvider(widget.groupId, widget.payment.id ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final saved = await ref.read(_provider.notifier).submit();
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final name = widget.payment.member?.displayName ?? '';
    return AppSheetBody(
      title: l10n.markPaidTitle(name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Rupiah.format(widget.payment.amount ?? 0), style: t.amountXl.copyWith(color: c.textPrimary)),
          SectionHeader(title: l10n.markPaidMethod, top: AppSpace.s5),
          _MethodChips(provider: _provider),
          const SizedBox(height: AppSpace.s4),
          _NoteField(provider: _provider, controller: _note),
          const SizedBox(height: AppSpace.s4),
          _ConfirmAndSubmit(provider: _provider, onSubmit: _submit),
        ],
      ),
    );
  }
}

class const _MethodChips({required final MarkPaidControllerProvider provider}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final method = ref.watch(provider.select((s) => s.method));
    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      children: [
        for (final m in PaymentMethod.values)
          AppChip(
            label: switch (m) {
              PaymentMethod.cash => l10n.paymentMethodCash,
              PaymentMethod.transfer => l10n.paymentMethodTransfer,
              PaymentMethod.other => l10n.paymentMethodOther,
            },
            selected: m == method,
            onSelected: () => ref.read(provider.notifier).setMethod(m),
          ),
      ],
    );
  }
}

class const _NoteField({
  required final MarkPaidControllerProvider provider,
  required final TextEditingController controller,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final length = ref.watch(provider.select((s) => s.note.trim().length));
    final tooLong = length > MarkPaidUseCase.maxNoteLength;
    return AppTextField(
      controller: controller,
      label: l10n.markPaidNoteLabel,
      hint: l10n.markPaidNoteHint,
      counter: '$length/${MarkPaidUseCase.maxNoteLength}',
      errorText: tooLong ? l10n.markPaidNoteTooLong : null,
      maxLines: 3,
      minLines: 1,
      onChanged: ref.read(provider.notifier).setNote,
    );
  }
}

class const _ConfirmAndSubmit({
  required final MarkPaidControllerProvider provider,
  required final VoidCallback onSubmit,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final state = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckRow(
          label: l10n.markPaidConfirm,
          value: state.confirmed,
          onChanged: state.submitting ? null : ref.read(provider.notifier).setConfirmed,
        ),
        if (state.failure case final failure?) ...[
          const SizedBox(height: AppSpace.s2),
          Text(failure.displayMessage, style: t.caption.copyWith(color: c.rejected.fg)),
        ],
        const SizedBox(height: AppSpace.s5),
        AppButton(
          label: l10n.markPaidSubmit,
          block: true,
          loading: state.submitting,
          disabledReason: state.confirmed ? null : l10n.markPaidCheckFirst,
          onPressed: state.canSubmit ? onSubmit : null,
        ),
      ],
    );
  }
}
