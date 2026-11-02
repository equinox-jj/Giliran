import 'package:material_ui/material_ui.dart';

/// 4-point spacing scale.
abstract final class AppSpace() {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;
}

/// Corner radius scale.
abstract final class AppRadius() {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 36.0;
  static const full = 999.0;

  /// Checkbox corner.
  static const checkbox = 6.0;
}

/// Border and outline widths.
abstract final class AppStroke() {
  /// Ink outline on kunyit shapes, circle buttons and tokens.
  static const ink = 1.5;

  /// Input, outline button and hairline ring width.
  static const regular = 1.5;

  /// Focus and error borders, selected choice cards.
  static const strong = 2.0;

  static const dash = 4.0;
  static const dashGap = 3.0;
}

/// Builders for continuous-corner (squircle) shapes.
abstract final class AppShapes() {
  /// Continuous (squircle) corners that look like [radius] circular corners.
  static ContinuousRectangleBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(radius * 2.2),
    side: side,
  );

  /// Squircle with only the top corners rounded (bottom sheets).
  static ContinuousRectangleBorder squircleTop(double radius) => ContinuousRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(radius * 2.2),
    ),
  );

  static const pill = StadiumBorder();
}
