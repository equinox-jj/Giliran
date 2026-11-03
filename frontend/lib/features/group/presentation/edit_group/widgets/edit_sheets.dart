import 'package:material_ui/material_ui.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

/// Sheet body with [child] above a block "Simpan" button that pops [value].
class const _SaveSheet<T>({
  required final String title,
  required final Widget child,
  required final T? Function() value,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: AppSpace.s6),
          AppButton(
            label: context.l10n.saveButton,
            block: true,
            onPressed: () => Navigator.of(context).pop(value()),
          ),
        ],
      ),
    );
  }
}

/// Edits a text setting such as the group name; pops the new text.
class const TextValueSheet({
  super.key,
  required final String title,
  required final String label,
  required final String initial,
}) extends StatefulWidget {
  @override
  State<TextValueSheet> createState() => _TextValueSheetState();
}

class _TextValueSheetState() extends State<TextValueSheet> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SaveSheet<String>(
    title: widget.title,
    value: () => _text.text,
    child: AppTextField(
      controller: _text,
      label: widget.label,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
    ),
  );
}

/// Edits a rupiah amount; pops the new amount.
class const AmountValueSheet({
  super.key,
  required final String title,
  required final String label,
  required final int initial,
}) extends StatefulWidget {
  @override
  State<AmountValueSheet> createState() => _AmountValueSheetState();
}

class _AmountValueSheetState() extends State<AmountValueSheet> {
  late final TextEditingController _text;
  int? _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.initial;
    _text = TextEditingController(text: Rupiah.digits(widget.initial));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SaveSheet<int>(
    title: widget.title,
    value: () => _amount,
    child: AmountField(controller: _text, label: widget.label, onChanged: (v) => _amount = v),
  );
}

/// Edits a whole number within bounds (slots, reminder days); pops it.
class const StepperValueSheet({
  super.key,
  required final String title,
  required final String label,
  required final int initial,
  required final int min,
  required final int max,
  final String? unit,
}) extends StatefulWidget {
  @override
  State<StepperValueSheet> createState() => _StepperValueSheetState();
}

class _StepperValueSheetState() extends State<StepperValueSheet> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) => _SaveSheet<int>(
    title: widget.title,
    value: () => _value,
    child: AppStepper(
      label: widget.label,
      value: _value,
      min: widget.min,
      max: widget.max,
      unit: widget.unit,
      onChanged: (v) => setState(() => _value = v),
    ),
  );
}

/// Picks one of a few options (period, draw method); pops the choice.
class const ChoiceValueSheet<T>({
  super.key,
  required final String title,
  required final List<ChoiceOption<T>> options,
  required final T initial,
}) extends StatefulWidget {
  @override
  State<ChoiceValueSheet<T>> createState() => _ChoiceValueSheetState<T>();
}

class _ChoiceValueSheetState<T>() extends State<ChoiceValueSheet<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) => _SaveSheet<T>(
    title: widget.title,
    value: () => _value,
    child: ChoiceCardGroup<T>(options: widget.options, value: _value, onChanged: (v) => setState(() => _value = v)),
  );
}
