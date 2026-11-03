import 'model/profile_model.dart';
import 'model/session_model.dart';
import 'model/update_me_request_model.dart';

/// The `/me` profile endpoints. Every method throws a typed `AppException`
/// on failure.
abstract interface class ProfileRemoteDataSource() {
  /// `GET /me`.
  Future<ProfileDataModel> getMe();

  /// `PATCH /me`: name (2–50 chars) and the optional WhatsApp number.
  /// [clearPhone] sends `phone: null`, which removes the number.
  Future<ProfileDataModel> updateMe(
    UpdateMeRequestModel body, {
    bool clearPhone = false,
  });

  /// `PUT /me/avatar`: uploads the image at [path] as multipart `file`.
  /// [onProgress] gets the sent fraction (0–1).
  Future<ProfileDataModel> uploadAvatar(
    String path, {
    void Function(double progress)? onProgress,
  });

  /// `DELETE /me/avatar`: back to the initials avatar.
  Future<void> deleteAvatar();

  /// `GET /me/sessions`: active devices, current one first.
  Future<List<SessionModel>> getSessions();

  /// `DELETE /me/sessions/{id}`: signs that device out.
  Future<void> revokeSession(String sessionId);

  /// `POST /me/deletion` with the PIN. Every session is revoked on success.
  Future<void> deleteAccount(String pin);
}
