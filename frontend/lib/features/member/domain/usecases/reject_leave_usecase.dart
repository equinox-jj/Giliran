import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/leave_request.dart';
import '../entities/member_input.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'reject_leave_usecase.g.dart';

typedef RejectLeaveParams = ({String groupId, String requestId, String? reason});

/// Rejects a leave request (S31). A reason, when given, must be 3–500
/// characters.
class const RejectLeaveUseCase(final MemberRepository _repository) implements UseCase<LeaveRequest, RejectLeaveParams> {
  @override
  Future<Either<Failure, LeaveRequest>> call(RejectLeaveParams params) async {
    final errors = MemberRules.checkReason(params.reason, minLength: MemberRules.minRejectReasonLength);
    if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    final reason = params.reason?.trim();
    return _repository.rejectLeave(
      params.groupId,
      params.requestId,
      reason: reason == null || reason.isEmpty ? null : reason,
    );
  }
}

@Riverpod(keepAlive: true)
RejectLeaveUseCase rejectLeaveUseCase(Ref ref) => RejectLeaveUseCase(ref.watch(memberRepositoryProvider));
