import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'join_group_usecase.g.dart';

/// Joins the group behind an invite code and takes the next free slot (feature 17).
class const JoinGroupUseCase(final MemberRepository _repository) implements UseCase<Member, String> {
  @override
  Future<Either<Failure, Member>> call(String params) => _repository.joinGroup(params.trim().toUpperCase());
}

@Riverpod(keepAlive: true)
JoinGroupUseCase joinGroupUseCase(Ref ref) => JoinGroupUseCase(ref.watch(memberRepositoryProvider));
