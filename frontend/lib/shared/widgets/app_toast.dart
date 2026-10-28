import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// Shows a toast: a floating ink pill above the nav for 4 s, with an optional
/// action ("Batal") in kunyit. Announced to screen readers.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  double bottomOffset = 0,
}) {
  final c = context.colors;
  final t = AppTextStyles.of(context);
  final view = View.of(context);
  SemanticsService.sendAnnouncement(view, message, Directionality.of(context));

  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverse,
      elevation: 0,
      shape: AppShapes.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s5,
        vertical: 14,
      ),
      margin: EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4 + bottomOffset,
      ),
      content: Text(
        message,
        style: t.body.copyWith(
          color: c.textOnInverse,
          fontWeight: FontWeight.w500,
        ),
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: c.turn,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
