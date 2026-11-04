import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'watch_member_usecase.g.dart';

/// One cached member, live; `null` until fetched or once gone.
class const WatchMemberUseCase(final MemberRepository _repository) implements StreamUseCase<Member?, String> {
  @override
  Stream<Either<Failure, Member?>> call(String params) => _repository.watchMember(params);
}

@Riverpod(keepAlive: true)
WatchMemberUseCase watchMemberUseCase(Ref ref) => WatchMemberUseCase(ref.watch(memberRepositoryProvider));
