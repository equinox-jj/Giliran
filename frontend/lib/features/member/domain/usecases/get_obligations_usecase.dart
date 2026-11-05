import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/obligation.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'get_obligations_usecase.g.dart';

/// What past winners still owe, overdue members first (most overdue
/// dues first), then by the period they won.
class const GetObligationsUseCase(final MemberRepository _repository) implements UseCase<List<Obligation>, String> {
  @override
  Future<Either<Failure, List<Obligation>>> call(String params) async {
    final result = await _repository.getObligations(params);
    return result.map(
      (list) => [...list]
        ..sort((a, b) {
          final overdue = (b.overdueCount ?? 0).compareTo(a.overdueCount ?? 0);
          return overdue != 0 ? overdue : (a.wonPeriodNo ?? 0).compareTo(b.wonPeriodNo ?? 0);
        }),
    );
  }
}

@Riverpod(keepAlive: true)
GetObligationsUseCase getObligationsUseCase(Ref ref) => GetObligationsUseCase(ref.watch(memberRepositoryProvider));
