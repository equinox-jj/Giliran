/// Payment status as stored by the API (`payments.status`).
enum PaymentStatus(final String apiValue) {
  unpaid('unpaid'),
  pendingReview('pending_review'),
  paid('paid'),
  rejected('rejected');

  /// Returns the status for an API [value]; unrecognized values become
  /// [PaymentStatus.unpaid].
  static PaymentStatus fromApi(String value) => PaymentStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => PaymentStatus.unpaid,
  );
}
