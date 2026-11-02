import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/biometric_status.dart';
import '../../../domain/usecases/get_biometric_status_usecase.dart';
import '../../../domain/usecases/set_biometric_enabled_usecase.dart';

part 'biometric_controller.g.dart';

/// Biometric unlock for the S07 opt-in, the S08 key and the S47 toggle.
@riverpod
class BiometricController() extends _$BiometricController {
  @override
  Future<BiometricStatus> build() => _load();

  /// "Aktifkan" (true) or "Nanti saja" (false) on S07, or the S47 toggle.
  /// Returns the [Failure] when the choice could not be saved.
  Future<Failure?> setEnabled(bool enabled) async {
    final result = await ref.read(setBiometricEnabledUseCaseProvider)(enabled);
    if (!ref.mounted) return result.getLeft().toNullable();
    if (result.isRight()) state = await AsyncValue.guard(_load);

    return result.getLeft().toNullable();
  }

  Future<BiometricStatus> _load() async {
    final result = await ref.read(getBiometricStatusUseCaseProvider)(const NoParams());

    return result.fold((failure) => throw failure, (status) => status);
  }
}
