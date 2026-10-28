import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';

enum AppBannerVariant {
  info(AppIcons.info),
  warning(AppIcons.hourglassMedium),
  error(AppIcons.warningCircle),
  offline(AppIcons.cloudSlash),
  success(AppIcons.checkCircle);

  const AppBannerVariant(this.icon);

  final String icon;

  StatusColors colorsOf(GiliranColors c) => switch (this) {
    AppBannerVariant.info => c.info,
    AppBannerVariant.warning => c.pending,
    AppBannerVariant.error => c.rejected,
    AppBannerVariant.offline => c.unpaid,
    AppBannerVariant.success => c.paid,
  };
}

/// Full-width inline message at the top of content. Dismissible only when
/// the information isn't needed to act.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.variant = AppBannerVariant.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final AppBannerVariant variant;

  /// Overrides the variant's default icon.
  final String? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = variant.colorsOf(context.colors);
    final t = AppTextStyles.of(context);
    final text = t.body.copyWith(color: colors.fg);

    return Semantics(
      container: true,
      liveRegion: variant == AppBannerVariant.error,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              icon ?? variant.icon,
              size: AppSizes.iconMd,
              color: colors.fg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: AppSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(message, style: text),
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
                label: 'Tutup',
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
