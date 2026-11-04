import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/features/draw/domain/entities/draw.dart';
import 'package:giliran/features/draw/domain/repositories/draw_repository.dart';

/// Records each run with its key and `confirmIncomplete` flag. A run answers
/// from [runResults] (for retries) before [runResult].
class FakeDrawRepository() implements DrawRepository {
  final calls = <String>[];
  final keys = <String>[];
  final confirms = <bool>[];

  Either<Failure, Draw> drawResult = const Right(Draw(periodId: 'p1'));
  Either<Failure, Draw> runResult = const Right(Draw(periodId: 'p1'));

  /// Answers for the next runs, in order, before [runResult].
  final runResults = <Either<Failure, Draw>>[];

  @override
  Future<Either<Failure, Draw>> getDraw(String groupId, String periodId) async {
    calls.add('getDraw');
    return drawResult;
  }

  @override
  Future<Either<Failure, Draw>> runDraw(
    String groupId,
    String periodId, {
    required bool confirmIncomplete,
    required IdempotencyKey key,
  }) async {
    calls.add('runDraw');
    keys.add(key.value);
    confirms.add(confirmIncomplete);
    return runResults.isNotEmpty ? runResults.removeAt(0) : runResult;
  }
}
