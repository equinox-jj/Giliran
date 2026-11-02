import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entity/profile.dart';

/// The signed-in user's own profile (`/me`).
abstract interface class ProfileRepository() {
  /// `PATCH /me`. A null field is left as it is on the server.
  Future<Either<Failure, ProfileData>> updateMe({String? name, String? phone});
}
