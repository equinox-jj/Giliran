/// The named, frozen algorithm a draw used (`Draw.algorithm`, DB_SCHEME §5).
/// A new algorithm gets a new name; these never change.
enum DrawAlgorithm(final String apiValue) {
  /// Commit-reveal: HMAC-SHA256 of the period id keyed by the seed.
  hmacSha256V1('hmac-sha256-v1'),

  /// The next unwon slot in the fixed order; no seed.
  fixedOrderV1('fixed-order-v1');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static DrawAlgorithm? fromApi(String? value) => DrawAlgorithm.values.where((e) => e.apiValue == value).firstOrNull;
}
