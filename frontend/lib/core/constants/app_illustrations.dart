/// Paths of the multi-color illustrations in `assets/images/illustrations/`.
/// Each SVG is drawn in the light palette (ink strokes, page and surface
/// fills, kunyit, pandan and tone spots); `Illustration` swaps those colors
/// for the current theme, so one file serves light and dark.
abstract final class AppIllustrations() {
  static const splashKaleng = 'assets/images/illustrations/splash_kaleng.svg';

  static const onboardingTikar = 'assets/images/illustrations/onboarding_tikar.svg';

  static const onboardingProof = 'assets/images/illustrations/onboarding_proof.svg';

  static const onboardingTrust = 'assets/images/illustrations/onboarding_trust.svg';

  static const emailSlip = 'assets/images/illustrations/email_slip.svg';

  /// An envelope with a small hourglass: the email code card (8.35).
  static const emailWaiting = 'assets/images/illustrations/email_waiting.svg';

  static const biometricUnlock = 'assets/images/illustrations/biometric_unlock.svg';
}
