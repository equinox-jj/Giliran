import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Package names the bundled third-party licenses appear under on the
/// license page (S42 "Lisensi").
abstract final class AppLicenses() {
  static const phosphor = 'Phosphor Icons';
  static const plusJakartaSans = 'Plus Jakarta Sans';
  static const jetBrainsMono = 'JetBrains Mono';

  static const _files = {
    phosphor: 'assets/licenses/phosphor-MIT.txt',
    plusJakartaSans: 'assets/licenses/PlusJakartaSans-OFL.txt',
    jetBrainsMono: 'assets/licenses/JetBrainsMono-OFL.txt',
  };
}

/// Adds the icon and font licenses that ship as assets (not pub packages) to
/// [LicenseRegistry], so `showLicensePage` lists them. Called once from
/// `main`.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: package, value: path) in AppLicenses._files.entries) {
      yield LicenseEntryWithLineBreaks([package], await rootBundle.loadString(path));
    }
  });
}
