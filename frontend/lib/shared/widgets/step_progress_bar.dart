import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';

/// "1 dari 2" over a segmented 4 px bar, ink for done and current steps and
/// hairline for the rest. Create group (S13–S14) puts it in the top bar,
/// beside the close or back button.
class const StepProgressBar({
  super.key,

  /// 1-based.
  required final int step,
  required final int total,
}) extends StatelessWidget {
  static const _height = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final label = context.l10n.stepOf(step, total);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: t.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: AppSpace.s1),
                  Expanded(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.base,
                      height: _height,
                      decoration: ShapeDecoration(
                        color: i <= step ? c.textPrimary : c.hairline,
                        shape: AppShapes.pill,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
