/// What must be true before a group can start (Readiness checklist, 8.29).
/// Each kind matches a `409` code of `POST /start`.
enum ReadinessKind() {
  slots,
  paymentInfo,
  fixedOrder,
}

/// One checklist row and whether it already passes.
final class const ReadinessItem({required final ReadinessKind kind, required final bool done});
