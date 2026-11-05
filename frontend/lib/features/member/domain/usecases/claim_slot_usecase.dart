import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'claim_slot_usecase.g.dart';

/// Claims a guest slot with the signed-in account. Returns the group id when it can be told.
class const ClaimSlotUseCase(final MemberRepository _repository) implements UseCase<String?, String> {
  @override
  Future<Either<Failure, String?>> call(String params) => _repository.claimSlot(params);
}

@Riverpod(keepAlive: true)
ClaimSlotUseCase claimSlotUseCase(Ref ref) => ClaimSlotUseCase(ref.watch(memberRepositoryProvider));
