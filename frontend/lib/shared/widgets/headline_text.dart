import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// The mixed-weight screen headline: the fact in bold, the framing regular.
/// Mark the single bold run with `**`:
///
/// ```dart
/// HeadlineText('Periode 4 dari 10, **8 orang sudah bayar**.')
/// ```
class HeadlineText extends StatelessWidget {
  const HeadlineText(this.text, {super.key, this.color, this.textAlign});

  final String text;
  final Color? color;
  final TextAlign? textAlign;

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
    final base = t.headline.copyWith(
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
class HeadlineBlock extends StatelessWidget {
  const HeadlineBlock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s2, bottom: AppSpace.s6),
    child: HeadlineText(text),
  );
}
