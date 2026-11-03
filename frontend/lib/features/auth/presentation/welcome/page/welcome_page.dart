import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_illustrations.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

class const WelcomePage({super.key, required final VoidCallback onSignIn}) extends StatefulWidget {
  static const pages = [
    OnboardingPageData(
      illustration: AppIllustrations.onboardingTikar,
      toneIndex: 0,
      headline: 'Arisan rapi, **semua bisa cek**.',
      body:
          'Catat iuran tiap periode, lihat siapa yang sudah bayar, dan '
          'buktikan setiap kocokan. Semua anggota melihat papan yang sama.',
    ),
    OnboardingPageData(
      illustration: AppIllustrations.onboardingProof,
      toneIndex: 1,
      headline: 'Kocokan yang **bisa dibuktikan**.',
      body:
          'Setiap kocokan menghasilkan Bukti Kocok. Siapa pun di grup bisa '
          'cek ulang hasilnya, tidak ada yang bisa mengatur pemenang.',
    ),
    OnboardingPageData(
      illustration: AppIllustrations.onboardingTrust,
      toneIndex: 2,
      headline: 'Giliran **tidak pernah memegang uang** kamu.',
      body:
          'Iuran tetap ditransfer langsung ke pengurus seperti biasa. '
          'Giliran hanya mencatat, supaya semua anggota bisa melihat.',
    ),
  ];

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState() extends State<WelcomePage> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == WelcomePage.pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: AppMotion.emphasis,
        curve: AppMotion.baseCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.page,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.screenMargin,
            AppSpace.s4,
            context.screenMargin,
            AppSpace.s8,
          ),
          child: context.isCompact
              ? _PhoneLayout(
                  controller: _controller,
                  index: _index,
                  isLast: _isLast,
                  onPageChanged: (i) => setState(() => _index = i),
                  onSkip: () => _goTo(WelcomePage.pages.length - 1),
                  onNext: () => _goTo(_index + 1),
                  onSignIn: widget.onSignIn,
                )
              : _WideLayout(onSignIn: widget.onSignIn),
        ),
      ),
    );
  }
}

/// Phone: the pager, then "Lanjut" (or sign-in on the last page).
class const _PhoneLayout({
  required final PageController controller,
  required final int index,
  required final bool isLast,
  required final ValueChanged<int> onPageChanged,
  required final VoidCallback onSkip,
  required final VoidCallback onNext,
  required final VoidCallback onSignIn,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopRow(
          trailing: isLast
              ? null
              : AppButton.ghost(
                  label: 'Lewati',
                  semanticLabel: 'Lewati ke halaman terakhir',
                  size: AppButtonSize.small,
                  onPressed: onSkip,
                ),
        ),
        const SizedBox(height: AppSpace.s3),
        Expanded(
          child: OnboardingPager(
            pages: WelcomePage.pages,
            controller: controller,
            index: index,
            onPageChanged: onPageChanged,
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        if (isLast)
          _SignInButton(onPressed: onSignIn)
        else
          AppButton(
            label: 'Lanjut',
            trailingIcon: AppIcons.arrowRight,
            block: true,
            onPressed: onNext,
          ),
        const SizedBox(height: 14),
        // Kept on the last page too (hidden) so the button does not jump.
        Opacity(
          opacity: isLast ? 0 : 1,
          child: ExcludeSemantics(
            excluding: isLast,
            child: Text(
              'Giliran tidak pernah memegang uang kamu.',
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tablet: the first illustration left, the three points stacked right.
class const _WideLayout({required final VoidCallback onSignIn}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final first = WelcomePage.pages.first;
    const pages = WelcomePage.pages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TopRow(),
        const SizedBox(height: AppSpace.s6),
        Expanded(
          child: MaxWidth.board(
            child: Row(
              spacing: context.gutter,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => OnboardingPanel(
                      illustration: first.illustration,
                      toneIndex: first.toneIndex,
                      height: constraints.maxHeight,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    // shrinkWrap keeps the short list vertically centered.
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pages.length + 1,
                      itemBuilder: (context, i) =>
                          i < pages.length ? _WidePoint(pages[i]) : _SignInButton(onPressed: onSignIn),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One promise on the tablet layout: headline, body, then a gap.
class const _WidePoint(final OnboardingPageData page) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeadlineText(page.headline),
          const SizedBox(height: AppSpace.s2),
          Text(
            page.body,
            style: t.bodyLg.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Wordmark left, optional action right, 48 high.
class const _TopRow({final Widget? trailing}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppTextStyles.of(context);

    return SizedBox(
      height: AppSizes.tapMin,
      child: Row(
        children: [
          Text(
            'giliran',
            style: t.titleLg.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: context.colors.textPrimary,
            ),
          ),
          const Spacer(),
          // The ghost button's 18 px padding would sit the label 6 px further
          // in than the design's 12; pull it out to the margin line.
          if (trailing case final trailing?) Transform.translate(offset: const Offset(6, 0), child: trailing),
        ],
      ),
    );
  }
}

class const _SignInButton({required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppButton(
    label: 'Masuk dengan email',
    icon: AppIcons.envelopeSimple,
    block: true,
    onPressed: onPressed,
  );
}
