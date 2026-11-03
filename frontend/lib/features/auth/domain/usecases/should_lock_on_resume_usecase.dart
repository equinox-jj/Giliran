import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';

part 'should_lock_on_resume_usecase.g.dart';

/// When the app left the foreground, and when it came back.
typedef ShouldLockOnResumeParams = ({DateTime hiddenAt, DateTime now});

/// Whether an open session locks again on resume: after [autoLockAfter] or
/// more in the background (FR-AUTH-03).
class const ShouldLockOnResumeUseCase() implements UseCase<bool, ShouldLockOnResumeParams> {
  static const autoLockAfter = Duration(minutes: 5);

  @override
  Future<Either<Failure, bool>> call(ShouldLockOnResumeParams params) async =>
      Right(params.now.difference(params.hiddenAt) >= autoLockAfter);
}

@Riverpod(keepAlive: true)
ShouldLockOnResumeUseCase shouldLockOnResumeUseCase(Ref ref) => const ShouldLockOnResumeUseCase();
