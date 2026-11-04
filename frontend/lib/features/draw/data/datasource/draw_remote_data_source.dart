import '../../../../core/network/idempotency.dart';
import 'model/draw_model.dart';

/// The draw endpoints. Draws need a connection, so nothing here is cached.
abstract interface class DrawRemoteDataSource() {
  Future<DrawModel> getDraw(String groupId, String periodId);

  /// Runs the draw. [confirmIncomplete] proceeds although not every payment
  /// is paid (after a `payments_incomplete` answer).
  Future<DrawModel> runDraw(String groupId, String periodId, {bool confirmIncomplete, required IdempotencyKey key});
}
