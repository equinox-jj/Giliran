import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'delete_qris_usecase.g.dart';

/// Removes the organizer's QRIS image.
class const DeleteQrisUseCase(final GroupRepository _repository) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String params) => _repository.deleteQris(params);
}

@Riverpod(keepAlive: true)
DeleteQrisUseCase deleteQrisUseCase(Ref ref) => DeleteQrisUseCase(ref.watch(groupRepositoryProvider));
