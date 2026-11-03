import 'package:fpdart/fpdart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/l10n/locale_controller.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/user_settings.dart';
import '../../../domain/usecases/clear_image_cache_usecase.dart';
import '../../../domain/usecases/get_settings_usecase.dart';
import '../../../domain/usecases/update_settings_usecase.dart';

part 'settings_controller.g.dart';

/// The account settings on Settings (S47). Toggles apply at once and revert
/// when the server rejects them.
@riverpod
class SettingsController() extends _$SettingsController {
  @override
  Future<UserSettings> build() => _load();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Applies [patch] now and sends it. Returns the failure after reverting
  /// when the server kept the old values.
  Future<Failure?> change(UserSettingsPatch patch) async {
    final previous = state.value;
    if (previous == null) return null;
    state = AsyncData(
      previous.copyWith(
        language: patch.language ?? previous.language,
        notifyPaymentReminders: patch.notifyPaymentReminders ?? previous.notifyPaymentReminders,
        notifyDrawResults: patch.notifyDrawResults ?? previous.notifyDrawResults,
        notifyGroupActivity: patch.notifyGroupActivity ?? previous.notifyGroupActivity,
      ),
    );
    final result = await ref.read(updateSettingsUseCaseProvider)(patch);
    if (!ref.mounted) return result.getLeft().toNullable();
    switch (result) {
      case Left(:final value):
        state = AsyncData(previous);
        return value;
      case Right(value: final saved?):
        state = AsyncData(saved);
      case Right():
        break;
    }
    return null;
  }

  /// Saves the language on the account (for notifications and email) and
  /// switches the app to it without a restart (FR-PROF-04).
  Future<Failure?> setLanguage(String code) async {
    final failure = await change(UserSettingsPatch(language: code));
    if (failure == null && ref.mounted) {
      await ref.read(localeControllerProvider.notifier).set(Locale(code));
    }
    return failure;
  }

  /// "Hapus cache gambar". Returns the failure when it could not clear.
  Future<Failure?> clearImageCache() async {
    final result = await ref.read(clearImageCacheUseCaseProvider)(const NoParams());
    return result.getLeft().toNullable();
  }

  Future<UserSettings> _load() async {
    final result = await ref.read(getSettingsUseCaseProvider)(const NoParams());
    return result.fold((failure) => throw failure, (settings) => settings);
  }
}
