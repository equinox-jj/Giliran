import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/draw_algorithm.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/draw_status.dart';
import 'package:giliran/features/draw/domain/entities/draw.dart';
import 'package:giliran/features/draw/domain/usecases/verify_draw_usecase.dart';

import '../../fixtures.dart';

/// One vector of `backend/internal/draw/testdata/golden.json`.
typedef _Vector = ({
  String seed,
  String seedHash,
  String periodId,
  List<String> eligible,
  int index,
  String winner,
});

List<_Vector> _loadVectors() {
  final json = jsonDecode(File('test/fixtures/draw_golden.json').readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final v in (json['vectors'] as List).cast<Map<String, dynamic>>())
      (
        seed: v['seed'] as String,
        seedHash: v['seed_hash'] as String,
        periodId: v['period_id'] as String,
        eligible: (v['eligible_slot_ids'] as List).cast<String>(),
        index: v['index'] as int,
        winner: v['winner_slot_id'] as String,
      ),
  ];
}

Draw _draw(_Vector v, {String? seed, String? seedHash, String? periodId, List<String>? eligible, String? winner}) {
  final ids = eligible ?? v.eligible;
  return Draw(
    periodId: periodId ?? v.periodId,
    method: DrawMethod.random,
    algorithm: DrawAlgorithm.hmacSha256V1,
    status: DrawStatus.drawn,
    seed: seed ?? v.seed,
    seedHash: seedHash ?? v.seedHash,
    // Slot numbers follow the golden list order, which is sorted.
    eligibleSlots: [for (var i = 0; i < ids.length; i++) DrawSlot(slotId: ids[i], slotNo: i + 1)],
    winner: DrawSlot(slotId: winner ?? v.winner),
  );
}

List<int> _bytes(String hex) => [for (var j = 0; j < hex.length; j += 2) int.parse(hex.substring(j, j + 2), radix: 16)];

void main() {
  const useCase = VerifyDrawUseCase();
  final vectors = _loadVectors();

  test('the golden file has every backend vector', () {
    // Assert
    expect(vectors, hasLength(6));
  });

  for (final (i, v) in vectors.indexed) {
    test('golden vector $i picks index ${v.index} and verifies', () {
      // Arrange
      final draw = _draw(v);

      // Act
      final index = VerifyDrawUseCase.pickIndex(
        key: _bytes(v.seed),
        periodId: v.periodId,
        eligibleCount: v.eligible.length,
      );
      final result = useCase(draw);

      // Assert
      expect(index, v.index);
      expect(v.eligible[index!], v.winner);
      expect(result.hashMatches, isTrue);
      expect(result.winnerMatches, isTrue);
    });
  }

  group('detects tampering with vector 0', () {
    final v = vectors.first;
    final other = v.eligible[(v.index + 1) % v.eligible.length];

    final cases = <String, (Draw, bool, bool)>{
      'other winner': (_draw(v, winner: other), true, false),
      'other seed': (_draw(v, seed: '11${v.seed.substring(2)}'), false, false),
      'other hash': (_draw(v, seedHash: '00${v.seedHash.substring(2)}'), false, true),
      'other period': (_draw(v, periodId: '0193a1b2-c3d4-7e5f-8a6b-ffffffffffff'), true, false),
      'eligible list dropped a slot': (_draw(v, eligible: v.eligible.sublist(1)), true, false),
      'uppercase seed': (_draw(v, seed: 'AB${v.seed.substring(2)}'), false, false),
      'short seed': (_draw(v, seed: v.seed.substring(0, 62)), false, false),
      'non-hex seed': (_draw(v, seed: 'zz${v.seed.substring(2)}'), false, false),
    };

    for (final MapEntry(key: name, value: (draw, hash, winner)) in cases.entries) {
      test('$name gives hash $hash, winner $winner', () {
        // Act
        final result = useCase(draw);

        // Assert
        expect(result.hashMatches, hash);
        expect(result.winnerMatches, winner);
      });
    }
  });

  test('sorts eligible slots by slot number before picking', () {
    // Arrange
    final draw = drawnDraw.copyWith(eligibleSlots: drawnDraw.eligibleSlots!.reversed.toList());

    // Act
    final result = useCase(draw);

    // Assert
    expect(result.matches, isTrue);
  });

  test('a fixed-order draw passes without a seed', () {
    // Arrange
    const draw = Draw(
      method: DrawMethod.fixedOrder,
      algorithm: DrawAlgorithm.fixedOrderV1,
      status: DrawStatus.drawn,
      winner: DrawSlot(slotId: 's1'),
    );

    // Act
    final result = useCase(draw);

    // Assert
    expect(result.matches, isTrue);
  });

  test('a draw without a winner or slots does not match', () {
    // Arrange
    final draw = drawnDraw.copyWith(eligibleSlots: const [], winner: null);

    // Act
    final result = useCase(draw);

    // Assert
    expect(result.hashMatches, isTrue);
    expect(result.winnerMatches, isFalse);
  });
}
