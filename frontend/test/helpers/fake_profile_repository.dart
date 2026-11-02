import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/domain/repository/profile_repository.dart';

/// Answers `updateMe` with [updateResult], or echoes the sent fields back.
class FakeProfileRepository() implements ProfileRepository {
  Either<Failure, ProfileData>? updateResult;
  ({String? name, String? phone})? lastUpdate;

  @override
  Future<Either<Failure, ProfileData>> updateMe({String? name, String? phone}) async {
    lastUpdate = (name: name, phone: phone);
    return updateResult ?? Right(ProfileData(name: name, phone: phone));
  }
}
