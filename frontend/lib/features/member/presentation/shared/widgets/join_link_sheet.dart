import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/usecases/parse_invite_code_usecase.dart';

/// Opens Home's "Gabung lewat link" sheet. Resolves to the invite code the
/// user pasted or typed.
Future<String?> showJoinLinkSheet(BuildContext context) =>
    showAppSheet<String>(context, builder: (_) => const JoinLinkSheet());

/// A field for an invite link or code; "Lanjut" pops the code it reads.
class const JoinLinkSheet({super.key}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<JoinLinkSheet> createState() => _JoinLinkSheetState();
}

class _JoinLinkSheetState() extends ConsumerState<JoinLinkSheet> {
  final _text = TextEditingController();
  var _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _continue() {
    final code = ref.read(parseInviteCodeUseCaseProvider)(_text.text);
    if (code == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return AppSheetBody(
      title: l10n.joinLinkSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.joinLinkSheetHelp, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.s4),
          AppTextField(
            controller: _text,
            label: l10n.joinLinkField,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.go,
            errorText: _invalid ? l10n.joinLinkInvalid : null,
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _continue(),
          ),
          const SizedBox(height: AppSpace.s6),
          AppButton(label: l10n.joinLinkContinue, block: true, onPressed: _continue),
        ],
      ),
    );
  }
}
