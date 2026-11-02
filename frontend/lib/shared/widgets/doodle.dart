import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// A monoline doodle from `AppDoodles`, stroked in `text.primary` (cream in
/// dark mode). Always decorative: excluded from semantics. Never place one on
/// a money decision (proof review, payout, delete account).
class Doodle extends StatelessWidget {
  const Doodle(
    this.asset, {
    super.key,
    this.size = 120,
    this.color,
    this.opacity = 1,
  });

  /// Hero corner doodle: 120 px at 40% opacity.
  const Doodle.corner(this.asset, {super.key, this.color}) : size = 120, opacity = 0.4;

  final String asset;
  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.textPrimary;
    return ExcludeSemantics(
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          c.withValues(alpha: c.a * opacity),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
