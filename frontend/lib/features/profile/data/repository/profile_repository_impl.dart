import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entity/profile.dart';
import '../../domain/entity/session.dart';
import '../../domain/repository/profile_repository.dart';
import '../datasource/model/update_me_request_model.dart';
import '../datasource/profile_remote_data_source.dart';
import '../datasource/profile_remote_data_source_impl.dart';
import '../mapper/profile_mapper.dart';

part 'profile_repository_impl.g.dart';

class ProfileRepositoryImpl(final ProfileRemoteDataSource _remote) with BaseRepository implements ProfileRepository {
  @override
  Future<Either<Failure, ProfileData>> updateMe({
    String? name,
    String? phone,
    bool clearPhone = false,
  }) => safeCall(() async {
    final user = await _remote.updateMe(
      UpdateMeRequestModel(name: name, phone: clearPhone ? null : phone),
      clearPhone: clearPhone,
    );

    return user.toEntity();
  });

  @override
  Future<Either<Failure, ProfileData>> uploadAvatar(
    String path, {
    void Function(double progress)? onProgress,
  }) => safeCall(() async {
    final user = await _remote.uploadAvatar(path, onProgress: onProgress);
    return user.toEntity();
  });

  @override
  Future<Either<Failure, Unit>> deleteAvatar() => safeCall(() async {
    await _remote.deleteAvatar();
    return unit;
  });

  @override
  Future<Either<Failure, List<Session>>> getSessions() => safeCall(() async {
    final sessions = await _remote.getSessions();
    return [for (final session in sessions) session.toEntity()];
  });

  @override
  Future<Either<Failure, Unit>> revokeSession(String sessionId) => safeCall(() async {
    await _remote.revokeSession(sessionId);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> deleteAccount(String pin) => safeCall(() async {
    await _remote.deleteAccount(pin);
    return unit;
  });
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
