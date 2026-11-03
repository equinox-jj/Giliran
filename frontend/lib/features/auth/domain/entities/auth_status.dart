import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../profile/domain/entity/profile.dart';
import 'email_otp_challenge.dart';

part 'auth_status.freezed.dart';

@freezed
sealed class AuthStatus with _$AuthStatus {
  const factory signedOut({bool? expired}) = AuthSignedOut;

  const factory otpPending({PendingOtp? pending}) = AuthOtpPending;

  const factory needsName({ProfileData? user}) = AuthNeedsName;

  const factory needsPin({ProfileData? user}) = AuthNeedsPin;

  const factory locked({ProfileData? user}) = AuthLocked;

  /// A complete session the user has unlocked.
  const factory unlocked({ProfileData? user}) = AuthUnlocked;
}
