import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'upload_qris_usecase.g.dart';

/// Uploads the organizer's QRIS image. The server decodes and validates
/// the code; an invalid one comes back as a field error on `file`.
class const UploadQrisUseCase(final GroupRepository _repository)
    implements UseCase<GroupDetail, ({String groupId, String path})> {
  @override
  Future<Either<Failure, GroupDetail>> call(({String groupId, String path}) params) =>
      _repository.uploadQris(params.groupId, params.path);
}

@Riverpod(keepAlive: true)
UploadQrisUseCase uploadQrisUseCase(Ref ref) => UploadQrisUseCase(ref.watch(groupRepositoryProvider));
