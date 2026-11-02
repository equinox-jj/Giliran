import 'package:json_annotation/json_annotation.dart';

/// What an email code request is for (`OtpPurpose` in the API). One OTP flow
/// serves sign-in, forgot PIN and change email.
@JsonEnum(valueField: 'apiValue')
enum OtpPurpose(final String apiValue) {
  signIn('sign_in'),
  resetPin('reset_pin'),
  changeEmail('change_email');

  /// Returns the purpose for an API [value], or null when it is unknown.
  static OtpPurpose? fromApi(String? value) {
    for (final purpose in OtpPurpose.values) {
      if (purpose.apiValue == value) return purpose;
    }
    return null;
  }
}
