import 'package:material_ui/material_ui.dart';

import '../../../core/themes/themes.dart';

/// Opens a Tikar bottom sheet: `radius.xl` top corners, `bg.surfaceRaised`,
/// a 36×4 drag handle, max 560 wide on tablet, over the scrim. In dark mode a
/// hairline replaces the shadow.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool tall = false,
}) {
  final c = context.colors;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: true,
    shape: ContinuousRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl * 2.2),
      ),
      side: dark ? BorderSide(color: c.hairline) : BorderSide.none,
    ),
    constraints: BoxConstraints(
      maxWidth: AppSizes.contentMax,
      maxHeight: tall ? MediaQuery.sizeOf(context).height * 0.9 : double.infinity,
    ),
    builder: (context) => tall
        ? SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.9,
            child: builder(context),
          )
        : builder(context),
  );
}

/// Standard sheet body: optional `title`, content, and bottom padding that
/// follows the keyboard and the safe area.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.scrollable = true,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s6 + insets,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(
                title!,
                style: t.title.copyWith(color: c.textPrimary),
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.s1),
            Text(subtitle!, style: t.body.copyWith(color: c.textSecondary)),
          ],
          if (title != null || subtitle != null) const SizedBox(height: AppSpace.s4),
          child,
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}
