import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/problem_details.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/member.dart';
import '../entities/member_input.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'save_fixed_order_usecase.g.dart';

typedef SaveFixedOrderParams = ({String groupId, int totalSlots, List<FixedOrderEntry> order});

/// Saves the winning order of a fixed-order group (S17). Every slot must
/// appear exactly once with positions 1..[totalSlots]; anything else fails
/// with a [ValidationFailure] on `order` before any request.
class const SaveFixedOrderUseCase(final MemberRepository _repository)
    implements UseCase<List<Member>, SaveFixedOrderParams> {
  @override
  Future<Either<Failure, List<Member>>> call(SaveFixedOrderParams params) async {
    final order = params.order;
    final slots = {for (final e in order) e.slotId};
    final positions = {for (final e in order) e.position};
    final complete =
        order.length == params.totalSlots &&
        slots.length == order.length &&
        positions.length == order.length &&
        positions.every((p) => p >= 1 && p <= order.length);
    if (!complete) {
      return const Left(
        Failure.validation(
          fieldErrors: [FieldError(field: 'order', code: 'invalid', message: '')],
        ),
      );
    }
    return _repository.saveFixedOrder(params.groupId, order);
  }
}

@Riverpod(keepAlive: true)
SaveFixedOrderUseCase saveFixedOrderUseCase(Ref ref) => SaveFixedOrderUseCase(ref.watch(memberRepositoryProvider));
