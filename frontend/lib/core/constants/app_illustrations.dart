/// Paths of the multi-color illustrations in `assets/images/illustrations/`.
/// Each SVG is drawn in the light palette (ink strokes, page and surface
/// fills, kunyit, pandan and tone spots); `Illustration` swaps those colors
/// for the current theme, so one file serves light and dark.
abstract final class AppIllustrations() {
  /// Small kaleng with a kunyit lid: splash (S01).
  static const splashKaleng = 'assets/images/illustrations/splash_kaleng.svg';

  /// People on a tikar around a kaleng: Welcome page 1 (S02).
  static const onboardingTikar = 'assets/images/illustrations/onboarding_tikar.svg';

  /// Kocokan glass beside a sealed Bukti Kocok: Welcome page 2 (S02).
  static const onboardingProof = 'assets/images/illustrations/onboarding_proof.svg';

  /// Money passing hand to hand, the app beside it: Welcome page 3 (S02).
  static const onboardingTrust = 'assets/images/illustrations/onboarding_trust.svg';
}
