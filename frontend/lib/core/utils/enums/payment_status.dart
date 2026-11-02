/// Payment status as stored by the API (`payments.status`).
enum PaymentStatus {
  unpaid('unpaid'),
  pendingReview('pending_review'),
  paid('paid'),
  rejected('rejected');

  const PaymentStatus(this.apiValue);

  final String apiValue;

  /// Returns the status for an API [value]; unrecognized values become
  /// [PaymentStatus.unpaid].
  static PaymentStatus fromApi(String value) => PaymentStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => PaymentStatus.unpaid,
  );
}
