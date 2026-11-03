import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entity/profile.dart';
import '../entity/session.dart';

/// The signed-in user's own profile (`/me`).
abstract interface class ProfileRepository() {
  /// `PATCH /me`. A null field is left as it is on the server;
  /// [clearPhone] removes the WhatsApp number.
  Future<Either<Failure, ProfileData>> updateMe({
    String? name,
    String? phone,
    bool clearPhone = false,
  });

  /// `PUT /me/avatar` with the image at [path]; returns the updated profile.
  Future<Either<Failure, ProfileData>> uploadAvatar(
    String path, {
    void Function(double progress)? onProgress,
  });

  /// `DELETE /me/avatar`.
  Future<Either<Failure, Unit>> deleteAvatar();

  /// `GET /me/sessions`, current device first.
  Future<Either<Failure, List<Session>>> getSessions();

  /// `DELETE /me/sessions/{id}`.
  Future<Either<Failure, Unit>> revokeSession(String sessionId);

  /// `POST /me/deletion`. Fails with `pin_invalid`, `pin_locked` or
  /// `obligations_outstanding`.
  Future<Either<Failure, Unit>> deleteAccount(String pin);
}
