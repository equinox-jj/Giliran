import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'refresh_members_usecase.g.dart';

/// Fetches a group's members into the cache (server wins).
class const RefreshMembersUseCase(final MemberRepository _repository) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String params) => _repository.refreshMembers(params);
}

@Riverpod(keepAlive: true)
RefreshMembersUseCase refreshMembersUseCase(Ref ref) => RefreshMembersUseCase(ref.watch(memberRepositoryProvider));
