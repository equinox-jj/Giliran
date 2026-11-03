import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

class const StepPills({
  super.key,
  required final List<String> labels,

  /// Zero-based index of the step on screen.
  required final int current,
  final MainAxisAlignment alignment = MainAxisAlignment.start,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Langkah ${current + 1} dari ${labels.length}, ${labels[current]}',
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: alignment,
        spacing: 14,
        children: [
          for (var i = 0; i < labels.length; i++)
            _Pill(number: i + 1, label: labels[i], done: i < current, active: i == current),
        ],
      ),
    ),
  );
}

class const _Pill({
  required final int number,
  required final String label,
  required final bool done,
  required final bool active,
}) extends StatelessWidget {
  static const _dot = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = done
        ? c.paid.fg
        : active
        ? c.textPrimary
        : c.textTertiary;
    final digit = t.micro.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0, height: 1);

    final Widget dot = done
        ? Container(
            width: _dot,
            height: _dot,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.paid.fg, shape: BoxShape.circle),
            child: AppIcon(AppIcons.checkBold, size: 12, color: c.paid.bg),
          )
        : active
        ? Container(
            width: _dot,
            height: _dot,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.inverse, shape: BoxShape.circle),
            child: Text('$number', style: digit.copyWith(color: c.textOnInverse)),
          )
        : DashedBorder.circle(
            color: c.borderStrong,
            child: SizedBox.square(
              dimension: _dot,
              child: Center(
                child: Text('$number', style: digit.copyWith(color: c.textTertiary)),
              ),
            ),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        dot,
        Text(
          label,
          style: t.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0, color: color),
        ),
      ],
    );
  }
}
