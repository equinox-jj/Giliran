import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// Section header: `title` text with an optional `caption` subtitle and a
/// trailing action (text button, circle icon button or count chip).
/// Spacing 32 above (24 in tablet panes), 12 below.
class const SectionHeader({
  super.key,
  required final String title,
  final String? subtitle,
  final Widget? trailing,

  /// Overrides the space above (default 32 on compact, 24 otherwise).
  final double? top,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: top ?? (context.isCompact ? AppSpace.s8 : AppSpace.s6),
        bottom: AppSpace.s3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.title.copyWith(color: c.textPrimary),
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
          ?trailing,
        ],
      ),
    );
  }
}

/// Text button used in section headers and inline actions ("Lihat semua").
class const AppTextButton({
  super.key,
  required final String label,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.tapMin,
            minWidth: AppSizes.tapMin,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: t.label.copyWith(
                color: onPressed == null ? c.textTertiary : c.link,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
