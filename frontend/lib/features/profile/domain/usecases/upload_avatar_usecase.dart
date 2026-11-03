import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repository/profile_repository_impl.dart';
import '../entity/profile.dart';
import '../repository/profile_repository.dart';

part 'upload_avatar_usecase.g.dart';

/// The image file to upload and an optional sent-fraction (0–1) listener.
typedef UploadAvatarParams = ({String path, void Function(double progress)? onProgress});

class UploadAvatarUseCase(
  final ProfileRepository _profile,
  final AuthRepository _auth,
) implements UseCase<ProfileData, UploadAvatarParams> {
  @override
  Future<Either<Failure, ProfileData>> call(UploadAvatarParams params) async {
    final result = await _profile.uploadAvatar(
      params.path,
      onProgress: params.onProgress,
    );
    if (result case Right(value: final user)) {
      // The server has the photo; a failed cache write only delays showing it.
      await _auth.saveCurrentUser(user);
    }
    return result;
  }
}

@Riverpod(keepAlive: true)
UploadAvatarUseCase uploadAvatarUseCase(Ref ref) => UploadAvatarUseCase(
  ref.watch(profileRepositoryProvider),
  ref.watch(authRepositoryProvider),
);
