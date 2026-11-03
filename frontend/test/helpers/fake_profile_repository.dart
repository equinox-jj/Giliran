import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/domain/entity/session.dart';
import 'package:giliran/features/profile/domain/repository/profile_repository.dart';

/// Answers `updateMe` with [updateResult], or echoes the sent fields back.
/// Sessions come from [sessionsResult]; each revoke is recorded and answered
/// with [revokeResults] by id (default success). `deleteAccount` records the
/// PIN and answers with [deleteAccountResult].
/// `uploadAvatar` reports [uploadProgress] and then answers with
/// [uploadResult]; set [uploadGate] to hold it mid-upload.
class FakeProfileRepository() implements ProfileRepository {
  Either<Failure, ProfileData>? updateResult;
  ({String? name, String? phone})? lastUpdate;
  bool? lastClearPhone;

  Either<Failure, ProfileData> uploadResult = Right(
    ProfileData(avatarUrl: 'https://cdn.test/avatar.jpg'),
  );
  Either<Failure, Unit> deleteResult = const Right(unit);
  double uploadProgress = 0.5;
  Completer<void>? uploadGate;
  final uploadedPaths = <String>[];
  int deleteCalls = 0;

  @override
  Future<Either<Failure, ProfileData>> updateMe({
    String? name,
    String? phone,
    bool clearPhone = false,
  }) async {
    lastUpdate = (name: name, phone: phone);
    lastClearPhone = clearPhone;
    return updateResult ?? Right(ProfileData(name: name, phone: phone));
  }

  @override
  Future<Either<Failure, ProfileData>> uploadAvatar(
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    uploadedPaths.add(path);
    onProgress?.call(uploadProgress);
    await uploadGate?.future;
    return uploadResult;
  }

  @override
  Future<Either<Failure, Unit>> deleteAvatar() async {
    deleteCalls++;
    return deleteResult;
  }

  Either<Failure, List<Session>> sessionsResult = const Right([]);
  final revokeResults = <String, Either<Failure, Unit>>{};
  final revokedIds = <String>[];
  Either<Failure, Unit> deleteAccountResult = const Right(unit);
  final deletedWithPins = <String>[];

  @override
  Future<Either<Failure, List<Session>>> getSessions() async => sessionsResult;

  @override
  Future<Either<Failure, Unit>> revokeSession(String sessionId) async {
    revokedIds.add(sessionId);
    return revokeResults[sessionId] ?? const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteAccount(String pin) async {
    deletedWithPins.add(pin);
    return deleteAccountResult;
  }
}
