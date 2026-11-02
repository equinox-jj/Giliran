import 'package:flutter/widgets.dart';

import 'app_sizes.dart';

/// Window-width thresholds, in logical pixels, where the layout changes from one
/// [SizeClass] to the next.
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
}

/// Layout class of the window, which sets the grid columns, screen margin and
/// gutter.
enum SizeClass {
  compact,
  medium,
  expanded;

  /// Returns the class for a window [width]: [SizeClass.expanded] from
  /// [Breakpoints.expanded], [SizeClass.medium] from [Breakpoints.medium], otherwise
  /// [SizeClass.compact].
  static SizeClass fromWidth(double width) {
    if (width >= Breakpoints.expanded) return SizeClass.expanded;
    if (width >= Breakpoints.medium) return SizeClass.medium;
    return SizeClass.compact;
  }

  int get columns => switch (this) {
    SizeClass.compact => 4,
    SizeClass.medium => 8,
    SizeClass.expanded => 12,
  };

  double get margin => switch (this) {
    SizeClass.compact => 20,
    SizeClass.medium => 32,
    SizeClass.expanded => 40,
  };

  double get gutter => switch (this) {
    SizeClass.compact => 12,
    SizeClass.medium => 16,
    SizeClass.expanded => 24,
  };
}

extension SizeClassX on BuildContext {
  /// Size class from the window width (not the device type).
  SizeClass get sizeClass => SizeClass.fromWidth(MediaQuery.sizeOf(this).width);

  double get screenMargin => sizeClass.margin;

  double get gutter => sizeClass.gutter;

  bool get isCompact => sizeClass == SizeClass.compact;
}

/// Centers content and caps its width (560 for reading, 1200 for boards).
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.width = AppSizes.contentMax,
  });

  const MaxWidth.board({super.key, required this.child})
    : width = AppSizes.boardMax;

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}
