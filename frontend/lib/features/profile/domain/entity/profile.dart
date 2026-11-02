import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';

/// The signed-in user's profile as the rest of the app sees it.
@freezed
abstract class Profile with _$Profile {
  factory({
    ProfileData? data,
  }) = _Profile;
}

/// Account details of a user: identity, contact info, avatar, and whether a PIN
/// has been set.
@freezed
abstract class ProfileData with _$ProfileData {
  factory({
    String? id,
    String? email,
    String? phone,
    String? name,
    String? avatarUrl,
    bool? pinSet,
    DateTime? createdAt,
  }) = _ProfileData;
}
