import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entity/profile.dart';
import '../../domain/repository/profile_repository.dart';
import '../datasource/model/update_me_request_model.dart';
import '../datasource/profile_remote_data_source.dart';
import '../datasource/profile_remote_data_source_impl.dart';
import '../mapper/profile_mapper.dart';

part 'profile_repository_impl.g.dart';

class ProfileRepositoryImpl(final ProfileRemoteDataSource _remote) with BaseRepository implements ProfileRepository {
  @override
  Future<Either<Failure, ProfileData>> updateMe({String? name, String? phone}) => safeCall(() async {
    final user = await _remote.updateMe(
      UpdateMeRequestModel(name: name, phone: phone),
    );

    return user.toEntity();
  });
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
