import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

/// JSON shape of the profile API response, using the backend's field names.
@freezed
abstract class ProfileModel with _$ProfileModel {
  const factory({
    @JsonKey(name: "data") ProfileDataModel? data,
  }) = _ProfileModel;

  factory fromJson(Map<String, dynamic> json) => _$ProfileModelFromJson(json);
}

/// JSON shape of the profile payload inside [ProfileModel].
@freezed
abstract class ProfileDataModel with _$ProfileDataModel {
  const factory({
    @JsonKey(name: "id") String? id,
    @JsonKey(name: "email") String? email,
    @JsonKey(name: "phone") String? phone,
    @JsonKey(name: "name") String? name,
    @JsonKey(name: "avatar_url") String? avatarUrl,
    @JsonKey(name: "pin_set") bool? pinSet,
    @JsonKey(name: "created_at") DateTime? createdAt,
  }) = _ProfileDataModel;

  factory fromJson(Map<String, dynamic> json) => _$ProfileDataModelFromJson(json);
}
