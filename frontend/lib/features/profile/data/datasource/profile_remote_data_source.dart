import 'model/profile_model.dart';
import 'model/update_me_request_model.dart';

/// The `/me` profile endpoints. Every method throws a typed `AppException`
/// on failure.
abstract interface class ProfileRemoteDataSource() {
  /// `GET /me`.
  Future<ProfileDataModel> getMe();

  /// `PATCH /me`: name (2–50 chars) and the optional WhatsApp number.
  Future<ProfileDataModel> updateMe(UpdateMeRequestModel body);

  /// `PUT /me/avatar`: uploads the image at [path] as multipart `file`.
  /// [onProgress] gets the sent fraction (0–1).
  Future<ProfileDataModel> uploadAvatar(
    String path, {
    void Function(double progress)? onProgress,
  });

  /// `DELETE /me/avatar`: back to the initials avatar.
  Future<void> deleteAvatar();
}
