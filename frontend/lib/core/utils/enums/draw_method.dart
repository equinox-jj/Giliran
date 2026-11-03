/// How a group picks each period's winner (`groups.draw_method`).
enum DrawMethod(final String apiValue) {
  random('random'),
  fixedOrder('fixed_order');

  /// Returns the value for an API [value], or `null` when it is missing or
  /// unknown.
  static DrawMethod? fromApi(String? value) => DrawMethod.values.where((e) => e.apiValue == value).firstOrNull;
}
