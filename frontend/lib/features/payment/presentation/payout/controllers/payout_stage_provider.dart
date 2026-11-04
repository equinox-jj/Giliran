import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/usecases/pick_payout_stage_usecase.dart';
import 'payout_controller.dart';

part 'payout_stage_provider.g.dart';

/// Which payout screen the viewer sees, from the group, the period and the
/// payout.
@riverpod
PayoutStage payoutStage(Ref ref, String groupId, String periodId) {
  final detail = ref.watch(groupDetailControllerProvider(groupId)).value;
  final payout = ref.watch(payoutControllerProvider(groupId, periodId)).payout;
  return ref.watch(pickPayoutStageUseCaseProvider)((
    group: detail?.group,
    period: detail?.periods.where((p) => p.id == periodId).firstOrNull,
    payout: payout,
  ));
}
