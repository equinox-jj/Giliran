/// How an organizer-recorded payment was made (`payments.method`).
enum PaymentMethod(final String apiValue) {
  cash('cash'),
  transfer('transfer'),
  other('other');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static PaymentMethod? fromApi(String? value) => PaymentMethod.values.where((e) => e.apiValue == value).firstOrNull;
}
