import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';

/// A changed field on an activity row's diff line: "Iuran ~~Rp150.000~~ →
/// Rp200.000".
class const ActivityRowDiff({required final String label, required final String before, required final String after});

/// One activity log entry (Tikar 8.23): a 32 circle with the action icon
/// on `bg.subtle`, the generated sentence, its time in `caption` and an
/// optional diff line per changed field. System entries (no actor) get an
/// ink circle in place of the app mark. Used by the Aktivitas tab (S23).
class const ActivityRow({
  super.key,
  required final String icon,
  required final String title,
  required final String time,
  final List<ActivityRowDiff> diffs = const [],
  final bool system = false,
}) extends StatelessWidget {
  static const leadingSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final label = [
      l10n.activityRowSemantics(title, time),
      for (final d in diffs) l10n.activityDiffSemantics(d.label, d.before, d.after),
    ].join('. ');
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Leading(icon: icon, system: system),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.body.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(time, style: t.caption.copyWith(color: c.textTertiary)),
                    for (final d in diffs) _DiffLine(diff: d),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _Leading({required final String icon, required final bool system}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: ActivityRow.leadingSize,
      height: ActivityRow.leadingSize,
      decoration: ShapeDecoration(color: system ? c.ink : c.subtle, shape: const CircleBorder()),
      alignment: Alignment.center,
      child: AppIcon(icon, size: AppSizes.iconSm, color: system ? c.page : c.textSecondary),
    );
  }
}

class const _DiffLine({required final ActivityRowDiff diff}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppTextStyles.of(context).caption.copyWith(color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: '${diff.label} '),
            TextSpan(
              text: diff.before,
              style: style.copyWith(decoration: TextDecoration.lineThrough, color: c.textTertiary),
            ),
            TextSpan(text: ' → ${diff.after}'),
          ],
        ),
      ),
    );
  }
}
