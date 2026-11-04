import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/enums/leave_request_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/leave_request.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'get_leave_requests_usecase.g.dart';

/// Leave requests, newest first: all for managers, own for members.
class const GetLeaveRequestsUseCase(final MemberRepository _repository)
    implements UseCase<List<LeaveRequest>, ({String groupId, LeaveRequestStatus? status})> {
  @override
  Future<Either<Failure, List<LeaveRequest>>> call(({String groupId, LeaveRequestStatus? status}) params) =>
      _repository.getLeaveRequests(params.groupId, status: params.status?.apiValue);
}

@Riverpod(keepAlive: true)
GetLeaveRequestsUseCase getLeaveRequestsUseCase(Ref ref) =>
    GetLeaveRequestsUseCase(ref.watch(memberRepositoryProvider));
