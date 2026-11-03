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

  /// An envelope with a rolled arisan slip: sign in (S03), forgot PIN (S09).
  static const emailSlip = 'assets/images/illustrations/email_slip.svg';

  /// An envelope with a small hourglass: the email code card (8.35).
  static const emailWaiting = 'assets/images/illustrations/email_waiting.svg';

  /// A hand holding a phone with a fingerprint: biometric opt-in (S07).
  static const biometricUnlock = 'assets/images/illustrations/biometric_unlock.svg';
}
