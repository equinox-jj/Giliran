import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'app_breakpoints.dart';

abstract final class AppFonts {
  static const sans = 'PlusJakartaSans';
  static const mono = 'JetBrainsMono';
}

/// The Tikar type scale. Sizes switch to the tablet scale from the `medium`
/// breakpoint (window width ≥ 600). Colors come from the ambient
/// `DefaultTextStyle` / theme, so apply them with `copyWith(color: …)`.
@immutable
class AppTextStyles {
  const AppTextStyles._(this.isLarge);

  const AppTextStyles.phone() : isLarge = false;

  const AppTextStyles.tablet() : isLarge = true;

  factory AppTextStyles.of(BuildContext context) =>
      AppTextStyles._(MediaQuery.sizeOf(context).width >= Breakpoints.medium);

  /// True from the `medium` breakpoint.
  final bool isLarge;

  static const tabularFigures = [FontFeature.tabularFigures()];

  TextStyle _s(
    double phone,
    double tablet,
    double phoneH,
    double tabletH,
    FontWeight weight, {
    double tracking = 0,
    List<FontFeature>? features,
    String family = AppFonts.sans,
  }) {
    final size = isLarge ? tablet : phone;
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: (isLarge ? tabletH : phoneH) / size,
      fontWeight: weight,
      letterSpacing: tracking,
      fontFeatures: features,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  TextStyle get display => _s(34, 44, 40, 50, FontWeight.w800, tracking: -1.0);
  TextStyle get headline => _s(26, 32, 32, 38, FontWeight.w400, tracking: -0.6);
  TextStyle get headlineStrong =>
      headline.copyWith(fontWeight: FontWeight.w700);
  TextStyle get titleLg => _s(20, 22, 26, 28, FontWeight.w700, tracking: -0.3);
  TextStyle get title => _s(17, 18, 22, 24, FontWeight.w600, tracking: -0.2);
  TextStyle get bodyLg => _s(16, 16, 24, 24, FontWeight.w400);
  TextStyle get body => _s(14, 15, 20, 22, FontWeight.w400);
  TextStyle get label => _s(14, 14, 18, 18, FontWeight.w600);
  TextStyle get caption => _s(12, 13, 16, 18, FontWeight.w500, tracking: 0.1);
  TextStyle get micro => _s(11, 11, 14, 14, FontWeight.w600, tracking: 0.4);
  TextStyle get amountXl => _s(
    40,
    48,
    44,
    52,
    FontWeight.w800,
    tracking: -1.2,
    features: tabularFigures,
  );
  TextStyle get amountLg => _s(
    24,
    26,
    28,
    30,
    FontWeight.w700,
    tracking: -0.5,
    features: tabularFigures,
  );
  TextStyle get amount =>
      _s(16, 16, 20, 20, FontWeight.w600, features: tabularFigures);
  TextStyle get mono => _s(
    13,
    14,
    18,
    20,
    FontWeight.w500,
    tracking: 0.2,
    family: AppFonts.mono,
  );
}

/// Rupiah formatting: `Rp200.000`, no decimals, no space.
abstract final class Rupiah {
  static final _fmt = NumberFormat.decimalPattern('id_ID');

  /// 200000 -> "200.000"
  static String digits(int amount) => _fmt.format(amount);

  /// 200000 -> "Rp200.000"
  static String format(int amount) =>
      amount < 0 ? '-Rp${digits(-amount)}' : 'Rp${digits(amount)}';

  /// Compact form for cards narrower than 160 px: "Rp2 jt", "Rp350 rb".
  static String compact(int amount) {
    String trim(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1).replaceAll('.', ',');
    if (amount >= 1000000000) return 'Rp${trim(amount / 1000000000)} M';
    if (amount >= 1000000) return 'Rp${trim(amount / 1000000)} jt';
    if (amount >= 1000) return 'Rp${trim(amount / 1000)} rb';
    return format(amount);
  }

  /// Large amount with a small "Rp" prefix (55%, w600) and a 2 px gap, for
  /// `amountXl` / `amountLg`.
  static TextSpan span(int amount, TextStyle style) => TextSpan(
    children: [
      TextSpan(
        text: 'Rp',
        style: style.copyWith(
          fontSize: style.fontSize! * 0.55,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      const WidgetSpan(child: SizedBox(width: 2)),
      TextSpan(text: digits(amount), style: style),
    ],
  );
}
