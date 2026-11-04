import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/member.dart';
import '../entities/member_input.dart';

part 'shuffle_order_usecase.g.dart';

/// "Acak urutan" on Fixed order (S17): a random winning order, plus the
/// entries `PUT /fixed-order` takes for an order (position 1 first).
///
/// Pure and synchronous, so it does not go through `UseCase`. [_random] is
/// injectable so tests get a fixed order.
class ShuffleOrderUseCase([final Random? _random]) {
  List<Member> call(List<Member> members) => [...members]..shuffle(_random);

  /// The positions of [order] as `FixedOrderRequest.order` entries.
  static List<FixedOrderEntry> entries(List<Member> order) => [
    for (var i = 0; i < order.length; i++) FixedOrderEntry(slotId: order[i].slotId ?? '', position: i + 1),
  ];
}

@Riverpod(keepAlive: true)
ShuffleOrderUseCase shuffleOrderUseCase(Ref ref) => ShuffleOrderUseCase();
