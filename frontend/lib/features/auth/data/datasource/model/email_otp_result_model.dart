import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/utils/enums/otp_purpose.dart';
import '../../../../profile/data/datasource/model/profile_model.dart';
import 'token_pair_model.dart';

part 'email_otp_result_model.freezed.dart';
part 'email_otp_result_model.g.dart';

/// JSON shape of `EmailOtpResult`, returned by a successful verify. [auth] is
/// set for `sign_in` and `reset_pin`, [user] for `change_email`.
@freezed
abstract class EmailOtpResultModel with _$EmailOtpResultModel {
  const factory EmailOtpResultModel({
    @JsonKey(
      name: 'purpose',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    OtpPurpose? purpose,
    @JsonKey(name: 'auth') AuthResultModel? auth,
    @JsonKey(name: 'user') ProfileDataModel? user,
  }) = _EmailOtpResultModel;

  factory EmailOtpResultModel.fromJson(Map<String, dynamic> json) => _$EmailOtpResultModelFromJson(json);
}

/// JSON shape of `AuthResult`: the signed-in user, their tokens, and whether
/// the app must still ask for a name (new user) or a PIN.
@freezed
abstract class AuthResultModel with _$AuthResultModel {
  const factory AuthResultModel({
    @JsonKey(name: 'user') ProfileDataModel? user,
    @JsonKey(name: 'tokens') TokenPairModel? tokens,
    @JsonKey(name: 'is_new_user') bool? isNewUser,
    @JsonKey(name: 'pin_set') bool? pinSet,
  }) = _AuthResultModel;

  factory AuthResultModel.fromJson(Map<String, dynamic> json) => _$AuthResultModelFromJson(json);
}
