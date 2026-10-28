import 'package:flutter/painting.dart';

/// Primitive colors of the Tikar design system. Only this file may contain
/// hex values; widgets read semantic colors from `context.colors`.
abstract final class AppPalette {
  // Kopi — warm neutrals.
  static const kopi50 = Color(0xFFFBF7F1);
  static const kopi100 = Color(0xFFF2ECE3);
  static const kopi200 = Color(0xFFE6DDD1);
  static const kopi300 = Color(0xFFCFC2B3);
  static const kopi400 = Color(0xFFA89A8C);
  static const kopi500 = Color(0xFF8F8072);
  static const kopi600 = Color(0xFF7D6E61);
  static const kopi700 = Color(0xFF5C4E42);
  static const kopi800 = Color(0xFF2E241D);
  static const kopi850 = Color(0xFF211A14);
  static const kopi900 = Color(0xFF1C1611);
  static const kopi950 = Color(0xFF15110D);
  static const cream = Color(0xFFF4EDE3);
  static const creamMuted = Color(0xFFBCAE9F);
  static const creamFaint = Color(0xFF968878);
  static const darkBorderStrong = Color(0xFF7E6F61);
  static const darkHairline = Color(0xFF3A2F26);
  static const darkSubtle = Color(0xFF2A221B);
  static const white = Color(0xFFFFFFFF);

  // Pandan — brand green, "paid".
  static const pandan50 = Color(0xFFEAF3E3);
  static const pandan100 = Color(0xFFDCEBD2);
  static const pandan200 = Color(0xFFC5DDB5);
  static const pandan300 = Color(0xFF9CCB86);
  static const pandan500 = Color(0xFF5E9A55);
  static const pandan700 = Color(0xFF2B6640);
  static const pandan800 = Color(0xFF22402E);
  static const pandan950 = Color(0xFF18301F);

  // Kunyit — turmeric, "now".
  static const kunyit50 = Color(0xFFFDF1D8);
  static const kunyit200 = Color(0xFFF9DDA0);
  static const kunyit300 = Color(0xFFF6C76A);
  static const kunyit400 = Color(0xFFF3AE3D);
  static const kunyit600 = Color(0xFFC47F12);
  static const kunyit800 = Color(0xFF7A4A04);
  static const kunyit950 = Color(0xFF3A2A0C);

  // Telang — butterfly pea, info.
  static const telang50 = Color(0xFFECEEFC);
  static const telang200 = Color(0xFFC9CEF4);
  static const telang300 = Color(0xFFAEB4F2);
  static const telang700 = Color(0xFF3A3E9C);
  static const telang800 = Color(0xFF2C2F5C);
  static const telang950 = Color(0xFF24264D);

  // Jambu — rose apple, social.
  static const jambu50 = Color(0xFFFCEDEA);
  static const jambu200 = Color(0xFFF5C6BC);
  static const jambu700 = Color(0xFF9A4A3E);
  static const jambu800 = Color(0xFF4A2A25);

  // Bata — terracotta brick, problems.
  static const bata50 = Color(0xFFFBE6DE);
  static const bata300 = Color(0xFFEE9C83);
  static const bata600 = Color(0xFFB2452B);
  static const bata700 = Color(0xFF93351F);
  static const bata950 = Color(0xFF3E1D14);

  // Scrims.
  static const scrimLight = Color(0x7A1C1611); // kopi-900 at 48%
  static const scrimDark = Color(0xA3000000); // black at 64%

  // Elevation shadow base (kopi-900).
  static const shadow = Color(0xFF1C1611);
}
