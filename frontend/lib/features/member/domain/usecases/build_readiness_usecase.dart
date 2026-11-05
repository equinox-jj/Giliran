import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/api_error_code.dart';
import '../../../../core/utils/enums/draw_method.dart';
import '../../../group/domain/entities/group.dart';
import '../entities/member.dart';
import '../entities/readiness.dart';

part 'build_readiness_usecase.g.dart';

/// The Start group checklist, the same checks `POST /start` makes:
/// every slot filled (`slots_not_filled`), payment info set
/// (`payment_info_missing`) and, for fixed-order groups only, every member
/// placed (`fixed_order_incomplete`).
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const BuildReadinessUseCase() {
  List<ReadinessItem> call(({GroupDetail group, List<Member> members}) params) {
    final group = params.group;
    final total = group.totalSlots ?? 0;
    final filled = group.filledSlots ?? params.members.length;
    return [
      ReadinessItem(kind: ReadinessKind.slots, done: total > 0 && filled >= total),
      ReadinessItem(kind: ReadinessKind.paymentInfo, done: group.paymentInfo?.hasBankAccount ?? false),
      if (group.drawMethod == DrawMethod.fixedOrder)
        ReadinessItem(
          kind: ReadinessKind.fixedOrder,
          done: params.members.length >= total && params.members.every((m) => m.fixedOrderPosition != null),
        ),
    ];
  }

  /// The checklist row a `POST /start` conflict points at.
  static ReadinessKind? kindFor(ApiErrorCode? code) => switch (code) {
    ApiErrorCode.slotsNotFilled => ReadinessKind.slots,
    ApiErrorCode.paymentInfoMissing => ReadinessKind.paymentInfo,
    ApiErrorCode.fixedOrderIncomplete => ReadinessKind.fixedOrder,
    _ => null,
  };
}

@Riverpod(keepAlive: true)
BuildReadinessUseCase buildReadinessUseCase(Ref ref) => const BuildReadinessUseCase();
