import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_model.freezed.dart';
part 'session_model.g.dart';

/// One active device from `GET /me/sessions`.
@freezed
abstract class SessionModel with _$SessionModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'device_name') String? deviceName,
    @JsonKey(name: 'device_platform') String? devicePlatform,
    @JsonKey(name: 'last_active_at') DateTime? lastActiveAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'is_current') bool? isCurrent,
  }) = _SessionModel;

  factory fromJson(Map<String, dynamic> json) => _$SessionModelFromJson(json);
}
