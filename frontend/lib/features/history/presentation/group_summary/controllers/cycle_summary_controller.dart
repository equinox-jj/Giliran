import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/cycle_summary.dart';
import '../../../domain/usecases/build_cycle_summary_usecase.dart';

part 'cycle_summary_controller.g.dart';

/// The Cycle Summary (S24) of a group, from its cached detail and periods;
/// null until the group is loaded.
@riverpod
CycleSummary? cycleSummary(Ref ref, String groupId) {
  final provider = groupDetailControllerProvider(groupId);
  final group = ref.watch(provider.select((s) => s.value?.group));
  final periods = ref.watch(provider.select((s) => s.value?.periods));
  if (group == null) return null;
  return ref.watch(buildCycleSummaryUseCaseProvider)((group: group, periods: periods ?? const []));
}
