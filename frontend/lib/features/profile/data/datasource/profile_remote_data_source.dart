import 'model/profile_model.dart';
import 'model/update_me_request_model.dart';

/// The `/me` profile endpoints. Every method throws a typed `AppException`
/// on failure.
abstract interface class ProfileRemoteDataSource() {
  /// `GET /me`.
  Future<ProfileDataModel> getMe();

  /// `PATCH /me`: name (2–50 chars) and the optional WhatsApp number.
  Future<ProfileDataModel> updateMe(UpdateMeRequestModel body);
}
