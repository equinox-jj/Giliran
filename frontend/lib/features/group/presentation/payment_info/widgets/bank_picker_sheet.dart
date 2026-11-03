import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/banks.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

/// Searchable list of Indonesian banks and e-wallets, ending with
/// "Lainnya". Pops the chosen name, or [other] for "Lainnya".
class const BankPickerSheet({super.key, final String? selected}) extends StatefulWidget {
  /// Popped when the organizer picks "Lainnya" and types the bank instead.
  static const other = '__other__';

  @override
  State<BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState() extends State<BankPickerSheet> {
  late final TextEditingController _query;
  var _banks = Banks.all;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(
      () => _banks = q.isEmpty
          ? Banks.all
          : [
              for (final b in Banks.all)
                if (b.toLowerCase().contains(q)) b,
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheetBody(
      title: l10n.bankLabel,
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SearchField(controller: _query, hint: l10n.bankSearchHint, onChanged: _filter),
          const SizedBox(height: AppSpace.s2),
          Flexible(
            child: ListView.builder(
              itemCount: _banks.length + 1,
              itemBuilder: (context, i) {
                final isOther = i == _banks.length;
                final name = isOther ? l10n.bankOther : _banks[i];
                return _BankRow(
                  name: name,
                  selected: !isOther && name == widget.selected,
                  onTap: () => Navigator.of(context).pop(isOther ? BankPickerSheet.other : name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class const _BankRow({required final String name, required final bool selected, required final VoidCallback onTap})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: name,
      selected: selected,
      shape: AppShapes.squircle(AppRadius.sm),
      scale: false,
      child: SizedBox(
        height: AppSizes.settingsRowH,
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: t.bodyLg.copyWith(color: c.textPrimary)),
            ),
            if (selected) AppIcon(AppIcons.check, size: AppSizes.iconMd, color: c.textPrimary),
          ],
        ),
      ),
    );
  }
}
