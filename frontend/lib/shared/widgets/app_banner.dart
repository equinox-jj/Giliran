import '../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'headline_text.dart';

enum AppBannerVariant(final String icon) {
  info(AppIcons.info),
  warning(AppIcons.hourglassMedium),
  error(AppIcons.warningCircle),
  offline(AppIcons.cloudSlash),
  success(AppIcons.checkCircle);

  StatusColors colorsOf(GiliranColors c) => switch (this) {
    AppBannerVariant.info => c.info,
    AppBannerVariant.warning => c.pending,
    AppBannerVariant.error => c.rejected,
    AppBannerVariant.offline => c.unpaid,
    AppBannerVariant.success => c.paid,
  };
}

/// Full-width inline message at the top of content. Dismissible only when
/// the information isn't needed to act. Mark a bold run in [message] with
/// `**`, as in `HeadlineText`.
class const AppBanner({
  super.key,
  required final String message,
  final AppBannerVariant variant = AppBannerVariant.info,

  /// Overrides the variant's default icon.
  final String? icon,
  final String? actionLabel,
  final VoidCallback? onAction,
  final VoidCallback? onDismiss,

  final bool note = false,

  final bool compact = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = variant.colorsOf(context.colors);
    final t = AppTextStyles.of(context);
    final small = note || compact;
    final text = small
        ? t.body.copyWith(color: colors.fg, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500)
        : t.body.copyWith(color: colors.fg);

    return Semantics(
      container: true,
      liveRegion: variant == AppBannerVariant.error,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : AppSpace.s4,
          vertical: compact ? 10 : AppSpace.s3,
        ),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            AppIcon(
              icon ?? variant.icon,
              size: compact ? 18 : AppSizes.iconMd,
              color: colors.fg,
            ),
            SizedBox(width: compact ? AppSpace.s2 : 10),
            Expanded(
              child: Wrap(
                spacing: AppSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final (part, bold) in HeadlineText.parse(message))
                          TextSpan(
                            text: part,
                            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
                          ),
                      ],
                    ),
                    style: text,
                  ),
                  if (actionLabel != null)
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: onAction,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            actionLabel!,
                            style: text.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: colors.fg,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              Semantics(
                button: true,
                label: context.l10n.commonClose,
                child: GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpace.s2,
                    ),
                    child: AppIcon(
                      AppIcons.x,
                      size: AppSizes.iconMd,
                      color: colors.fg,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
