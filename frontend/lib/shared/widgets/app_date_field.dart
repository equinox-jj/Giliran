import '../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/date_formatter.dart';
import 'adaptive/app_date_picker.dart';
import 'app_icon.dart';
import 'app_text_field.dart';

/// Looks like an input (56 high, `CalendarBlank` trailing); shows the value as
/// "Sab, 1 Nov 2026" and opens the platform picker on tap. [helper] says what
/// the date means.
class const AppDateField({
  super.key,
  required final DateTime? value,
  required final ValueChanged<DateTime> onChanged,
  required final DateTime firstDate,
  required final DateTime lastDate,
  final String? label,
  final String? hint,
  final String? helper,
  final String? errorText,
}) extends StatefulWidget {
  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState() extends State<AppDateField> {
  late final _controller = TextEditingController(text: _format(widget.value));

  String _format(DateTime? d) => d == null ? '' : AppDate.full(d);

  @override
  void didUpdateWidget(AppDateField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _controller.text = _format(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final initial = widget.value ?? widget.firstDate;
    final picked = await AppDatePicker.show(
      context,
      initialDate: initial,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: widget.label,
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: _controller,
    label: widget.label,
    hint: widget.hint ?? context.l10n.widgetPickDate,
    helper: widget.helper,
    errorText: widget.errorText,
    readOnly: true,
    onTap: _pick,
    semanticLabel: widget.label,
    suffix: Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpace.s3),
      child: AppIcon(
        AppIcons.calendarBlank,
        size: AppSizes.iconLg,
        color: context.colors.textSecondary,
      ),
    ),
  );
}
