import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/network/connectivity_controller.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../../member/presentation/shared/controllers/members_controller.dart';
import '../../../domain/usecases/plan_draw_stage_usecase.dart';

part 'draw_stage_plan_provider.g.dart';

/// The draw stage's plan from the cached group, period, members and
/// connection; null until the group and period are cached.
@riverpod
DrawStagePlan? drawStagePlan(Ref ref, String groupId, String periodId) {
  final detail = ref.watch(groupDetailControllerProvider(groupId)).value;
  final group = detail?.group;
  final period = detail?.periods.where((p) => p.id == periodId).firstOrNull;
  if (group == null || period == null) return null;
  final members = ref.watch(membersControllerProvider(groupId)).value ?? const [];
  final online = ref.watch(connectivityControllerProvider).value ?? true;
  final now = ref.watch(clockProvider)();
  return ref.watch(planDrawStageUseCaseProvider)((
    group: group,
    period: period,
    members: members,
    online: online,
    now: now,
  ));
}
