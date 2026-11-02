import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/biometric_kind.dart';

part 'biometric_status.freezed.dart';

/// Biometric unlock on this device: what the S07 opt-in, the S08 biometric
/// key and the S47 toggle need. [kind] is null when nothing is enrolled.
@freezed
abstract class BiometricStatus with _$BiometricStatus {
  const factory({
    BiometricKind? kind,
    bool? enabled,
    bool? shouldOffer,
  }) = _BiometricStatus;
}
