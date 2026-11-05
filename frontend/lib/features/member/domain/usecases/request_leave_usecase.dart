import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/leave_request.dart';
import '../entities/member_input.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'request_leave_usecase.g.dart';

/// Asks the organizer to let the caller leave. A blank reason is
/// left out; one over 500 characters fails before any request.
class const RequestLeaveUseCase(final MemberRepository _repository)
    implements UseCase<LeaveRequest, ({String groupId, String? reason})> {
  @override
  Future<Either<Failure, LeaveRequest>> call(({String groupId, String? reason}) params) async {
    final errors = MemberRules.checkReason(params.reason);
    if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    final reason = params.reason?.trim();
    return _repository.requestLeave(params.groupId, reason: reason == null || reason.isEmpty ? null : reason);
  }
}

@Riverpod(keepAlive: true)
RequestLeaveUseCase requestLeaveUseCase(Ref ref) => RequestLeaveUseCase(ref.watch(memberRepositoryProvider));
