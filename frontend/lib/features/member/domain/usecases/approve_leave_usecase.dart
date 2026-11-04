import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/leave_request.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'approve_leave_usecase.g.dart';

/// Approves a leave request; the member's slot becomes free.
class const ApproveLeaveUseCase(final MemberRepository _repository)
    implements UseCase<LeaveRequest, ({String groupId, String requestId})> {
  @override
  Future<Either<Failure, LeaveRequest>> call(({String groupId, String requestId}) params) =>
      _repository.approveLeave(params.groupId, params.requestId);
}

@Riverpod(keepAlive: true)
ApproveLeaveUseCase approveLeaveUseCase(Ref ref) => ApproveLeaveUseCase(ref.watch(memberRepositoryProvider));
