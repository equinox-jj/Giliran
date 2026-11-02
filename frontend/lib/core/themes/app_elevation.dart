import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

/// Shadows exist only for floating layers. In dark mode there are no
/// shadows; a 1 px hairline border separates layers instead.
abstract final class AppElevation {
  static const _floatLight = [
    BoxShadow(
      color: Color.fromRGBO(28, 22, 17, 0.10),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color.fromRGBO(28, 22, 17, 0.06),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  static const _sheetLight = [
    BoxShadow(
      color: Color.fromRGBO(28, 22, 17, 0.12),
      offset: Offset(0, -8),
      blurRadius: 32,
    ),
  ];

  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Bottom bar, floating pills, toasts, dragged rows.
  static List<BoxShadow> float(BuildContext context) => _isDark(context) ? const [] : _floatLight;

  /// Bottom sheets.
  static List<BoxShadow> sheet(BuildContext context) => _isDark(context) ? const [] : _sheetLight;

  /// Whether floating layers need a hairline border (dark mode).
  static bool needsHairline(BuildContext context) => _isDark(context);

  static const shadowColor = AppPalette.shadow;
}
