import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';

@freezed
abstract class Profile with _$Profile {
  factory Profile({
    ProfileData? data,
  }) = _Profile;
}

@freezed
abstract class ProfileData with _$ProfileData {
  factory ProfileData({
    String? id,
    String? email,
    String? phone,
    String? name,
    String? avatarUrl,
    bool? pinSet,
    DateTime? createdAt,
  }) = _ProfileData;
}
