import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/member.dart';

part 'next_free_slot_usecase.g.dart';

/// The slot a new member or guest takes: the lowest slot number from 1 to
/// `totalSlots` nobody holds, or null when the group is full. The server
/// assigns it the same way.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const NextFreeSlotUseCase() {
  int? call(({List<Member> members, int totalSlots}) params) {
    final taken = {for (final m in params.members) m.slotNo};
    for (var n = 1; n <= params.totalSlots; n++) {
      if (!taken.contains(n)) return n;
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
NextFreeSlotUseCase nextFreeSlotUseCase(Ref ref) => const NextFreeSlotUseCase();
