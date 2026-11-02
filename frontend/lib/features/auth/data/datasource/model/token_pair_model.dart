import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_pair_model.freezed.dart';
part 'token_pair_model.g.dart';

/// JSON shape of `TokenPair`: a 15-minute access token and a rotating
/// 30-day refresh token. Stays in the data layer; only secure storage sees it.
@freezed
abstract class TokenPairModel with _$TokenPairModel {
  const factory TokenPairModel({
    @JsonKey(name: 'access_token') String? accessToken,
    @JsonKey(name: 'refresh_token') String? refreshToken,
    @JsonKey(name: 'token_type') String? tokenType,
    @JsonKey(name: 'expires_in') int? expiresIn,
  }) = _TokenPairModel;

  factory TokenPairModel.fromJson(Map<String, dynamic> json) => _$TokenPairModelFromJson(json);
}
