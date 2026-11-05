import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/member.dart';

part 'sort_by_fixed_order_usecase.g.dart';

/// Members in their winning order for Fixed order: by
/// `fixed_order_position`, members without one last by slot number.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const SortByFixedOrderUseCase() {
  List<Member> call(List<Member> members) => [...members]
    ..sort((a, b) {
      final pa = a.fixedOrderPosition;
      final pb = b.fixedOrderPosition;
      if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
      if (pa != null && pb == null) return -1;
      if (pa == null && pb != null) return 1;
      return (a.slotNo ?? 0).compareTo(b.slotNo ?? 0);
    });
}

@Riverpod(keepAlive: true)
SortByFixedOrderUseCase sortByFixedOrderUseCase(Ref ref) => const SortByFixedOrderUseCase();
