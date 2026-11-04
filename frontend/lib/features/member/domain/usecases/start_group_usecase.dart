import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../group/domain/entities/group.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'start_group_usecase.g.dart';

/// Starts a draft group and opens period 1 (S18).
class const StartGroupUseCase(final MemberRepository _repository) implements UseCase<GroupDetail, String> {
  @override
  Future<Either<Failure, GroupDetail>> call(String params) => _repository.startGroup(params);
}

@Riverpod(keepAlive: true)
StartGroupUseCase startGroupUseCase(Ref ref) => StartGroupUseCase(ref.watch(memberRepositoryProvider));
