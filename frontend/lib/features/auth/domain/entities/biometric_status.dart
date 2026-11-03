import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/biometric_kind.dart';

part 'biometric_status.freezed.dart';

@freezed
abstract class BiometricStatus with _$BiometricStatus {
  const factory({
    BiometricKind? kind,
    bool? enabled,
    bool? shouldOffer,
  }) = _BiometricStatus;
}
