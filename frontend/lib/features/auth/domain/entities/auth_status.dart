import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../profile/domain/entity/profile.dart';
import 'email_otp_challenge.dart';

part 'auth_status.freezed.dart';

/// Where the user is in the sign-in journey on this device. The launch gate
/// (S01) and the router guard pick a route from it (design system 10.2).
@freezed
sealed class AuthStatus with _$AuthStatus {
  /// No session. [expired] is true when the server ended it, so S02 can show
  /// "Sesi kamu berakhir".
  const factory signedOut({bool? expired}) = AuthSignedOut;

  /// No session yet, but a code request is still open, so S04 resumes it.
  const factory otpPending({PendingOtp? pending}) = AuthOtpPending;

  /// Signed in as a new user who has not entered a name yet (S05).
  const factory needsName({ProfileData? user}) = AuthNeedsName;

  /// Signed in without a PIN on the account yet (S06).
  const factory needsPin({ProfileData? user}) = AuthNeedsPin;

  /// A complete session that still needs the PIN or biometric (S08).
  const factory locked({ProfileData? user}) = AuthLocked;

  /// A complete session the user has unlocked.
  const factory unlocked({ProfileData? user}) = AuthUnlocked;
}
