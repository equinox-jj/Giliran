import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/draw_algorithm.dart';
import '../entities/draw.dart';

part 'verify_draw_usecase.g.dart';

/// Recomputes a draw on the device, so members need not trust the
/// server's own "match" flags.
///
/// Must stay byte-for-byte equal to `backend/internal/draw/draw.go`
/// (`hmac-sha256-v1`, DB_SCHEME §5): the seed is 64 lowercase hex chars and
/// is hex-decoded before use; `seed_hash = hex(sha256(seed bytes))`; the HMAC
/// message is the lowercase period UUID string; the index is the first 8 MAC
/// bytes as a big-endian uint64 modulo the eligible count, over slots sorted
/// by slot number. Checked against the backend golden vectors in tests.
class const VerifyDrawUseCase() {
  static final _seedPattern = RegExp(r'^[0-9a-f]{64}$');

  DrawVerification call(Draw draw) {
    // Fixed order has no seed: the result is the next position, which the
    // server checks itself.
    if (draw.algorithm == DrawAlgorithm.fixedOrderV1) {
      return const DrawVerification(hashMatches: true, winnerMatches: true);
    }
    final seed = draw.seed;
    if (seed == null || !_seedPattern.hasMatch(seed)) {
      return const DrawVerification(hashMatches: false, winnerMatches: false);
    }
    final key = _hexDecode(seed);
    final hashMatches = sha256.convert(key).toString() == draw.seedHash;

    final eligible = [...?draw.eligibleSlots]..sort((a, b) => (a.slotNo ?? 0).compareTo(b.slotNo ?? 0));
    final index = pickIndex(key: key, periodId: draw.periodId ?? '', eligibleCount: eligible.length);
    final winnerId = draw.winner?.slotId;
    final winnerMatches = index != null && winnerId != null && eligible[index].slotId == winnerId;
    return DrawVerification(hashMatches: hashMatches, winnerMatches: winnerMatches);
  }

  /// The winning position among [eligibleCount] slots, or null when there
  /// are none. Public so the golden-vector test can check the index itself.
  static int? pickIndex({required List<int> key, required String periodId, required int eligibleCount}) {
    if (eligibleCount <= 0) return null;
    final mac = Hmac(sha256, key).convert(utf8.encode(periodId.toLowerCase())).bytes;
    // Dart's int is signed 64-bit, so the uint64 goes through BigInt.
    var value = BigInt.zero;
    for (final b in mac.take(8)) {
      value = (value << 8) | BigInt.from(b);
    }
    return (value % BigInt.from(eligibleCount)).toInt();
  }

  static Uint8List _hexDecode(String hex) => Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

@Riverpod(keepAlive: true)
VerifyDrawUseCase verifyDrawUseCase(Ref ref) => const VerifyDrawUseCase();
