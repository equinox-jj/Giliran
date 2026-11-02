import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/utils/enums/biometric_kind.dart';

/// Names and icons for a [BiometricKind] on S07 and the S08 biometric key.
extension BiometricCopy on BiometricKind {
  /// "Face ID" on iOS, "wajah" for other face unlock, else "sidik jari".
  String nameOn(TargetPlatform platform) => switch (this) {
    BiometricKind.face when platform == TargetPlatform.iOS => 'Face ID',
    BiometricKind.face => 'wajah',
    BiometricKind.fingerprint => 'sidik jari',
  };

  String get icon => switch (this) {
    BiometricKind.face => AppIcons.scanSmiley,
    BiometricKind.fingerprint => AppIcons.fingerprint,
  };
}
