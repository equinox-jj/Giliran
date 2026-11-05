import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/usecases/reject_payment_usecase.dart';

/// Opens the reject sheet for a proof from [name]: quick-pick reason
/// chips and a required 3–500 character reason. Resolves to the reason, or
/// null when cancelled.
Future<String?> showRejectReasonSheet(BuildContext context, {required String name}) => showAppSheet<String>(
  context,
  builder: (context) => _RejectReasonSheet(name: name),
);

class const _RejectReasonSheet({required final String name}) extends StatefulWidget {
  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState() extends State<_RejectReasonSheet> {
  final _reason = TextEditingController();
  var _touched = false;

  @override
  void initState() {
    super.initState();
    _reason.addListener(_onChanged);
  }

  @override
  void dispose() {
    _reason
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() => _touched = true);

  bool get _valid {
    final length = _reason.text.trim().length;
    return length >= RejectPaymentUseCase.minLength && length <= RejectPaymentUseCase.maxLength;
  }

  void _pick(String reason) {
    _reason.text = reason;
    _reason.selection = TextSelection.collapsed(offset: reason.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quick = [
      l10n.proofRejectReasonShort,
      l10n.proofRejectReasonBlurry,
      l10n.proofRejectReasonAccount,
      l10n.proofRejectReasonDate,
    ];
    final current = _reason.text.trim();
    return AppSheetBody(
      title: l10n.proofRejectTitle(widget.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (final reason in quick)
                AppChip(label: reason, selected: current == reason, onSelected: () => _pick(reason)),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          AppTextField(
            controller: _reason,
            hint: l10n.proofRejectHint,
            counter: '${current.length}/${RejectPaymentUseCase.maxLength}',
            errorText: _touched && !_valid ? l10n.proofRejectLength : null,
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: AppSpace.s5),
          AppButton(
            label: l10n.proofRejectSubmit,
            block: true,
            disabledReason: _valid ? null : l10n.proofRejectLength,
            onPressed: _valid ? () => Navigator.of(context).pop(current) : null,
          ),
        ],
      ),
    );
  }
}
