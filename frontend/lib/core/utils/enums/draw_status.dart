/// Whether a period's draw has run (`Draw.status`): `committed` means only
/// the seed hash is published, `drawn` means the seed and winner are out.
enum DrawStatus(final String apiValue) {
  committed('committed'),
  drawn('drawn');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static DrawStatus? fromApi(String? value) => DrawStatus.values.where((e) => e.apiValue == value).firstOrNull;
}
