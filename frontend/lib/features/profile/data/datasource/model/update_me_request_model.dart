// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_me_request_model.freezed.dart';
part 'update_me_request_model.g.dart';

/// Body of `PATCH /me`. Unset fields are left out, so the server keeps their
/// current values.
@freezed
abstract class UpdateMeRequestModel with _$UpdateMeRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory({
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'phone') String? phone,
  }) = _UpdateMeRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$UpdateMeRequestModelFromJson(json);
}
