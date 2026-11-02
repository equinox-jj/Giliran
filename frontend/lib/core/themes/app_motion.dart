import 'package:flutter/widgets.dart';

/// Animation durations and curves shared across the app.
abstract final class AppMotion {
  /// Press, chip select, toggles.
  static const quick = Duration(milliseconds: 120);

  /// Expand, fade, tab change.
  static const base = Duration(milliseconds: 220);

  /// Sheets, hero changes, ring fill.
  static const emphasis = Duration(milliseconds: 360);

  /// Winner reveal sequence.
  static const reveal = Duration(milliseconds: 900);

  /// Skeleton shimmer period.
  static const shimmer = Duration(milliseconds: 1200);

  static const quickCurve = Curves.easeOut;
  static const baseCurve = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0, 0, 1);

  /// Pressed scale for buttons and tappable surfaces.
  static const pressScale = 0.97;

  /// Whether the user asked the system to reduce animations. Callers should skip
  /// or shorten motion when this is `true`.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}
