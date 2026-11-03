import 'package:uuid/uuid.dart';

/// The `Idempotency-Key` for one user intent on a money or draw write.
///
/// Create it once when the user confirms (in the controller), pass it down
/// through usecase → repository → datasource, and reuse the same key on every
/// retry so the server records the action at most once. Datasources put
/// [value] in `extra[ApiEndpoints.kIdempotencyKey]`.
extension type const IdempotencyKey(String value) {
  factory IdempotencyKey.generate() => IdempotencyKey(const Uuid().v4());
}
