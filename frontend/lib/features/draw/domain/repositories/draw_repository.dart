import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../entities/draw.dart';

/// A period's draw, always fresh from the API (draws need a connection).
abstract interface class DrawRepository() {
  Future<Either<Failure, Draw>> getDraw(String groupId, String periodId);

  Future<Either<Failure, Draw>> runDraw(
    String groupId,
    String periodId, {
    required bool confirmIncomplete,
    required IdempotencyKey key,
  });
}
