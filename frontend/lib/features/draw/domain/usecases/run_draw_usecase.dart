import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../payment/data/repositories/payment_repository_impl.dart';
import '../../../payment/domain/repositories/payment_repository.dart';
import '../../data/repositories/draw_repository_impl.dart';
import '../entities/draw.dart';
import '../repositories/draw_repository.dart';

part 'run_draw_usecase.g.dart';

typedef RunDrawParams = ({String groupId, String periodId, bool confirmIncomplete, IdempotencyKey key});

/// Runs a period's draw. A `payments_incomplete` answer comes back as
/// a `ConflictFailure` carrying `paid_count` / `total_count`; the caller
/// confirms and sends again with `confirmIncomplete` and the **same** key.
/// After a draw the cached periods are refreshed so the strip and the hero
/// show the winner.
class const RunDrawUseCase(final DrawRepository _draws, final PaymentRepository _payments)
    implements UseCase<Draw, RunDrawParams> {
  @override
  Future<Either<Failure, Draw>> call(RunDrawParams params) async {
    final result = await _draws.runDraw(
      params.groupId,
      params.periodId,
      confirmIncomplete: params.confirmIncomplete,
      key: params.key,
    );
    // The draw is done either way; a failed cache refresh must not hide it.
    if (result.isRight()) await _payments.refreshPeriods(params.groupId);
    return result;
  }
}

@Riverpod(keepAlive: true)
RunDrawUseCase runDrawUseCase(Ref ref) =>
    RunDrawUseCase(ref.watch(drawRepositoryProvider), ref.watch(paymentRepositoryProvider));
