/// Display formats for invite and verification codes, hashes and slot numbers.
abstract final class CodeFormatter() {
  /// Groups a code in fours for reading: "7H2K 9QX4 MP". Copy the raw code,
  /// not this string.
  static String grouped(String code) {
    final buffer = StringBuffer();
    for (var i = 0; i < code.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(code.substring(i, i + 4 > code.length ? code.length : i + 4));
    }
    return buffer.toString();
  }

  /// Shortens a hex hash to its first and last four characters: "9f2c…a71e".
  static String hashShort(String hex) =>
      hex.length <= 9 ? hex : '${hex.substring(0, 4)}…${hex.substring(hex.length - 4)}';

  /// Two-digit slot number: "07".
  static String slotNo(int n) => n.toString().padLeft(2, '0');
}
