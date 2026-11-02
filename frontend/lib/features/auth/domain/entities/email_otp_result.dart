import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/otp_purpose.dart';
import '../../../profile/domain/entity/profile.dart';

part 'email_otp_result.freezed.dart';

/// The outcome of a verified email code. [auth] is set for `sign_in` and
/// `reset_pin`, [user] for `change_email`.
@freezed
abstract class EmailOtpResult with _$EmailOtpResult {
  const factory({
    OtpPurpose? purpose,
    AuthResult? auth,
    ProfileData? user,
  }) = _EmailOtpResult;
}

/// A started session: the signed-in user, and whether the app must still ask
/// for a name ([isNewUser]) or a PIN ([pinSet] false). The tokens stay in the
/// data layer.
@freezed
abstract class AuthResult with _$AuthResult {
  const factory({
    ProfileData? user,
    bool? isNewUser,
    bool? pinSet,
  }) = _AuthResult;
}
