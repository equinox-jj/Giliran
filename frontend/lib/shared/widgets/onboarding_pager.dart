import '../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/themes/themes.dart';
import 'headline_text.dart';
import 'illustration.dart';

/// One page of the [OnboardingPager].
@immutable
class const OnboardingPageData({
  /// Asset from `AppIllustrations`.
  required final String illustration,

  /// Index into `GiliranColors.tones` for the illustration panel.
  required final int toneIndex,

  /// Mixed-weight headline; mark the bold run with `**`.
  required final String headline,
  required final String body,
}) {}

/// Swipeable onboarding pages (8.13): a tone panel with the illustration,
/// the page dots, a headline and a `bodyLg` paragraph. The dots stay put
/// while the pages swipe under them. Buttons belong to the screen.
class const OnboardingPager({
  super.key,
  required final List<OnboardingPageData> pages,
  required final PageController controller,

  /// The current page, for the dots.
  required final int index,
  final ValueChanged<int>? onPageChanged,
}) extends StatelessWidget {
  static const _panelMaxH = 340.0;
  static const _dotsGap = 28.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelH = (constraints.maxHeight * 0.5).clamp(0.0, _panelMaxH);
        return Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: pages.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, i) => _Page(
                page: pages[i],
                panelHeight: panelH,
                textTop: _dotsGap + AppSpace.s2 + AppSpace.s5,
              ),
            ),
            Positioned(
              top: panelH + _dotsGap,
              left: 0,
              child: PageDots(count: pages.length, index: index),
            ),
          ],
        );
      },
    );
  }
}

class const _Page({
  required final OnboardingPageData page,
  required final double panelHeight,
  required final double textTop,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingPanel(
            illustration: page.illustration,
            toneIndex: page.toneIndex,
            height: panelHeight,
          ),
          SizedBox(height: textTop),
          // The onboarding headline is a size up: 30/36 on phones.
          HeadlineText(page.headline, style: t.headline.copyWith(fontSize: 30, height: 36 / 30)),
          const SizedBox(height: AppSpace.s3),
          Text(
            page.body,
            style: t.bodyLg.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The rounded tone panel holding an onboarding illustration.
class const OnboardingPanel({
  super.key,
  required final String illustration,
  required final int toneIndex,
  required final double height,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpace.s6),
      decoration: BoxDecoration(
        color: context.colors.tones[toneIndex].surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      alignment: Alignment.center,
      child: Illustration(illustration),
    );
  }
}

/// Page indicator: 8 px dots; the current one stretches to a 24 px kunyit
/// pill with an ink outline. Read as "Halaman 2 dari 3".
class const PageDots({super.key, required final int count, required final int index}) extends StatelessWidget {
  static const _dot = 8.0;
  static const _active = 24.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: context.l10n.widgetPageOf(index + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: reduceMotion ? Duration.zero : AppMotion.base,
                curve: AppMotion.baseCurve,
                width: i == index ? _active : _dot,
                height: _dot,
                decoration: ShapeDecoration(
                  color: i == index ? c.turn : c.dotIdle,
                  shape: StadiumBorder(
                    side: i == index ? BorderSide(color: c.ink, width: AppStroke.ink) : BorderSide.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
