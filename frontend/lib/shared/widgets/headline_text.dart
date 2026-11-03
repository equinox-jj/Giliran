import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// The mixed-weight screen headline: the fact in bold, the framing regular.
/// Mark the single bold run with `**`:
///
/// ```dart
/// HeadlineText('Periode 4 dari 10, **8 orang sudah bayar**.')
/// ```
class const HeadlineText(
  final String text, {
  super.key,
  final Color? color,
  final TextAlign? textAlign,

  /// Replaces the `headline` base style, such as the larger onboarding
  /// headline.
  final TextStyle? style,
}) extends StatelessWidget {
  static List<(String, bool)> parse(String text) {
    final parts = text.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty) (parts[i], i.isOdd),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTextStyles.of(context);
    final base = (style ?? t.headline).copyWith(
      color: color ?? context.colors.textPrimary,
    );
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            for (final (part, bold) in parse(text))
              TextSpan(
                text: part,
                style: bold ? base.copyWith(fontWeight: FontWeight.w700) : base,
              ),
          ],
        ),
        textAlign: textAlign,
      ),
    );
  }
}

/// The headline block under a headline top bar: 8 above, 24 below.
class const HeadlineBlock(final String text, {super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s2, bottom: AppSpace.s6),
    child: HeadlineText(text),
  );
}
