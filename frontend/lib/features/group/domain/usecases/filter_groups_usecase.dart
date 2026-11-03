import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/payment_status.dart';
import '../entities/group_summary.dart';

part 'filter_groups_usecase.g.dart';

/// The local chips on Home and the Groups list.
enum GroupChipFilter() {
  all,

  /// Saya pengurus: I organize or co-organize.
  managing,

  /// Saya anggota: I am a plain member.
  member,

  /// Belum bayar: my payment this period is unpaid or rejected.
  unpaid,
}

/// Narrows cached groups by a chip without a request. Pure and synchronous,
/// so it does not go through `UseCase`.
class const FilterGroupsUseCase() {
  List<GroupSummary> call(({List<GroupSummary> groups, GroupChipFilter filter}) params) => switch (params.filter) {
    GroupChipFilter.all => params.groups,
    GroupChipFilter.managing => [
      for (final g in params.groups)
        if (g.isManager) g,
    ],
    GroupChipFilter.member => [
      for (final g in params.groups)
        if (!g.isManager) g,
    ],
    GroupChipFilter.unpaid => [
      for (final g in params.groups)
        if (g.myPaymentStatus == PaymentStatus.unpaid || g.myPaymentStatus == PaymentStatus.rejected) g,
    ],
  };
}

@Riverpod(keepAlive: true)
FilterGroupsUseCase filterGroupsUseCase(Ref ref) => const FilterGroupsUseCase();
