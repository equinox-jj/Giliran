import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/utils/enums/biometric_kind.dart';

extension BiometricCopy on BiometricKind {
  /// "Face ID" on iOS, "wajah" for other face unlock, else "sidik jari"
  /// (in the app's language).
  String nameOn(AppLocalizations l10n, TargetPlatform platform) => switch (this) {
    BiometricKind.face when platform == TargetPlatform.iOS => l10n.authBiometricFaceId,
    BiometricKind.face => l10n.authBiometricFace,
    BiometricKind.fingerprint => l10n.authBiometricFingerprint,
  };

  String get icon => switch (this) {
    BiometricKind.face => AppIcons.scanSmiley,
    BiometricKind.fingerprint => AppIcons.fingerprint,
  };
}
