import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/usecases/refresh_members_usecase.dart';
import '../../../domain/usecases/save_fixed_order_usecase.dart';
import '../../../domain/usecases/shuffle_order_usecase.dart';
import '../../../domain/usecases/sort_by_fixed_order_usecase.dart';
import '../../../domain/usecases/watch_members_usecase.dart';

part 'fixed_order_controller.freezed.dart';
part 'fixed_order_controller.g.dart';

/// Fixed order: the order being edited, position 1 first.
@freezed
abstract class FixedOrderState with _$FixedOrderState {
  const factory({
    required List<Member> order,

    /// The order differs from the saved one.
    @Default(false) bool dirty,
    @Default(false) bool saving,
  }) = _FixedOrderState;
}

/// Loads the members in their saved order, edits it locally (drag, move
/// up/down, shuffle with undo) and saves it with `PUT /fixed-order`.
@riverpod
class FixedOrderController() extends _$FixedOrderController {
  @override
  Future<FixedOrderState> build(String groupId) async {
    // Offline the cached members still work.
    await ref.read(refreshMembersUseCaseProvider)(groupId);
    final cached = await ref.read(watchMembersUseCaseProvider)(groupId).first;
    return FixedOrderState(order: ref.read(sortByFixedOrderUseCaseProvider)(cached.getOrElse((_) => const [])));
  }

  /// Moves the member at [from] so it ends up at [to] (both final
  /// indexes).
  void move(int from, int to) {
    final current = state.value;
    if (current == null || from == to) return;
    final order = [...current.order];
    if (from < 0 || from >= order.length || to < 0 || to >= order.length) return;
    order.insert(to, order.removeAt(from));
    state = AsyncData(current.copyWith(order: order, dirty: true));
  }

  /// Shuffles the order. Returns the previous one for "Urungkan".
  List<Member>? shuffle() {
    final current = state.value;
    if (current == null) return null;
    state = AsyncData(current.copyWith(order: ref.read(shuffleOrderUseCaseProvider)(current.order), dirty: true));
    return current.order;
  }

  /// Puts back an order from before a shuffle.
  void restore(List<Member> order) {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(order: order, dirty: true));
  }

  /// Saves the order. Returns the failure, if any.
  Future<Failure?> save(int totalSlots) async {
    final current = state.value;
    if (current == null || current.saving) return null;
    state = AsyncData(current.copyWith(saving: true));
    final result = await ref.read(saveFixedOrderUseCaseProvider)((
      groupId: groupId,
      totalSlots: totalSlots,
      order: ShuffleOrderUseCase.entries(current.order),
    ));
    if (!ref.mounted) return result.getLeft().toNullable();
    state = AsyncData(
      switch (result) {
        Right(:final value) => current.copyWith(
          order: ref.read(sortByFixedOrderUseCaseProvider)(value),
          dirty: false,
          saving: false,
        ),
        Left() => current.copyWith(saving: false),
      },
    );
    return result.getLeft().toNullable();
  }
}
