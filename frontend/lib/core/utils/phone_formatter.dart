/// Indonesian phone numbers: input accepts 08…, 62…, +62…; storage is E.164.
abstract final class PhoneFormatter {
  /// "0812-3456-7890" / "62812…" / "+62 812…" -> "+6281234567890".
  /// Returns null when the input has no usable digits.
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('62')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+62$digits';
  }

  /// Local part without the country code, for the field after the +62 chip.
  static String localPart(String e164) =>
      e164.startsWith('+62') ? e164.substring(3) : e164;

  /// "+6281234567890" -> "+62 812-3456-7890".
  static String display(String e164) {
    final local = localPart(e164);
    final groups = <String>[];
    if (local.length > 3) {
      groups.add(local.substring(0, 3));
      var rest = local.substring(3);
      while (rest.length > 4) {
        groups.add(rest.substring(0, 4));
        rest = rest.substring(4);
      }
      if (rest.isNotEmpty) groups.add(rest);
    } else {
      groups.add(local);
    }
    return '+62 ${groups.join('-')}';
  }

  /// Minimal sanity check: 9–13 digits after +62, starting with 8.
  static bool isValid(String e164) => RegExp(r'^\+628\d{8,12}$').hasMatch(e164);
}
