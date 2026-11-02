import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Check box (22, radius 6, 1.5 px `border.strong`; checked = ink fill with
/// a cream bold check). The whole row is the hit area. Required consent rows
/// keep the primary button disabled until ticked.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final enabled = onChanged != null;

    final box = AnimatedContainer(
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.quick,
      width: AppSizes.checkbox,
      height: AppSizes.checkbox,
      decoration: BoxDecoration(
        color: value ? c.inverse : c.surface,
        borderRadius: BorderRadius.circular(AppRadius.checkbox),
        border: value
            ? null
            : Border.all(
                color: enabled ? c.borderStrong : c.hairline,
                width: AppStroke.regular,
              ),
      ),
      alignment: Alignment.center,
      child: value ? AppIcon(AppIcons.checkBold, size: 14, color: c.textOnInverse) : null,
    );

    return MergeSemantics(
      child: Semantics(
        checked: value,
        enabled: enabled,
        child: Pressable(
          onTap: enabled ? () => onChanged!(!value) : null,
          isButton: false,
          scale: false,
          shape: AppShapes.squircle(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
              child: Row(
                crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  box,
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: t.body.copyWith(
                            color: enabled ? c.textPrimary : c.textTertiary,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: t.caption.copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpace.s2),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
