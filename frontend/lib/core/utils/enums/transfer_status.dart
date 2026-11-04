/// An ownership transfer's state (`ownership_transfers.status`).
enum TransferStatus(final String apiValue) {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  cancelled('cancelled'),
  expired('expired');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static TransferStatus? fromApi(String? value) => TransferStatus.values.where((e) => e.apiValue == value).firstOrNull;
}
