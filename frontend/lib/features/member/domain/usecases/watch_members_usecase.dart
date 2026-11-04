import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'watch_members_usecase.g.dart';

/// A group's cached members by slot number, live.
class const WatchMembersUseCase(final MemberRepository _repository) implements StreamUseCase<List<Member>, String> {
  @override
  Stream<Either<Failure, List<Member>>> call(String params) => _repository.watchMembers(params);
}

@Riverpod(keepAlive: true)
WatchMembersUseCase watchMembersUseCase(Ref ref) => WatchMembersUseCase(ref.watch(memberRepositoryProvider));
