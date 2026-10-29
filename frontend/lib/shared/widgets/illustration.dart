import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';

/// A multi-color illustration from `AppIllustrations`. The SVG is drawn in
/// the light palette and its colors are mapped to the current theme (cream
/// strokes and dark tone spots in dark mode). Always decorative: excluded
/// from semantics.
class Illustration extends StatelessWidget {
  const Illustration(this.asset, {super.key, this.width, this.height});

  final String asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        asset,
        width: width,
        height: height,
        colorMapper: IllustrationColorMapper(context.colors),
      ),
    );
  }
}

/// Maps the light-palette colors an illustration is drawn with to [colors].
@immutable
class IllustrationColorMapper extends ColorMapper {
  const IllustrationColorMapper(this.colors);

  final GiliranColors colors;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final mapped = switch (color.withValues(alpha: 1)) {
      AppPalette.kopi900 => colors.textPrimary,
      AppPalette.kopi50 => colors.page,
      AppPalette.white => colors.surface,
      AppPalette.kunyit400 => colors.turn,
      AppPalette.pandan700 => colors.paid.fg,
      AppPalette.pandan50 => colors.paid.bg,
      AppPalette.pandan200 => colors.tones[0].surface,
      AppPalette.telang200 => colors.tones[1].surface,
      AppPalette.jambu200 => colors.tones[2].surface,
      _ => color,
    };
    return mapped.withValues(alpha: color.a);
  }

  @override
  bool operator ==(Object other) =>
      other is IllustrationColorMapper && other.colors == colors;

  @override
  int get hashCode => colors.hashCode;
}
