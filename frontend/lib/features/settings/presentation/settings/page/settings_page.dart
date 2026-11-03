import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/l10n/locale_controller.dart';
import '../../../../../core/themes/theme_mode_controller.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/user_settings.dart';
import '../controllers/settings_controller.dart';

/// Settings (S47): notification toggles, theme and language, the image
/// cache, and the way to Delete account.
class const SettingsPage({
  super.key,
  required final VoidCallback onDeleteAccount,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = context.screenMargin;

    return Scaffold(
      appBar: AppTopBar(title: l10n.settingsTitle),
      body: MaxWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s8),
          children: [
            const _Notifications(),
            SettingsGroup(
              header: l10n.settingsAppearance,
              children: const [_ThemeRow(), _LanguageRow()],
            ),
            SettingsGroup(
              header: l10n.settingsData,
              children: const [_ClearCacheRow()],
            ),
            SettingsGroup(
              children: [
                SettingsRow.destructive(
                  icon: AppIcons.trash,
                  label: l10n.settingsDeleteAccount,
                  onTap: onDeleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Notifikasi": the three toggles once the settings load.
class const _Notifications() extends ConsumerWidget {
  Future<void> _toggle(BuildContext context, WidgetRef ref, UserSettingsPatch patch) async {
    final failure = await ref.read(settingsControllerProvider.notifier).change(patch);
    if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);

    return switch (settings) {
      AsyncData(:final value) => SettingsGroup(
        header: l10n.settingsNotifications,
        children: [
          SettingsRow.toggle(
            icon: AppIcons.bellRinging,
            label: l10n.settingsNotifyPayment,
            subtitle: l10n.settingsNotifyPaymentHint,
            toggleValue: value.notifyPaymentReminders ?? false,
            onToggle: (on) => _toggle(context, ref, UserSettingsPatch(notifyPaymentReminders: on)),
          ),
          SettingsRow.toggle(
            icon: AppIcons.shuffle,
            label: l10n.settingsNotifyDraw,
            subtitle: l10n.settingsNotifyDrawHint,
            toggleValue: value.notifyDrawResults ?? false,
            onToggle: (on) => _toggle(context, ref, UserSettingsPatch(notifyDrawResults: on)),
          ),
          SettingsRow.toggle(
            icon: AppIcons.usersThree,
            label: l10n.settingsNotifyActivity,
            subtitle: l10n.settingsNotifyActivityHint,
            toggleValue: value.notifyGroupActivity ?? false,
            onToggle: (on) => _toggle(context, ref, UserSettingsPatch(notifyGroupActivity: on)),
          ),
        ],
      ),
      AsyncError() => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s6),
        child: AppBanner(
          message: l10n.settingsFailed,
          variant: AppBannerVariant.error,
          actionLabel: l10n.commonRetry,
          onAction: ref.read(settingsControllerProvider.notifier).reload,
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.only(bottom: AppSpace.s6),
        child: Skeleton(height: 3 * AppSizes.settingsRowHWithSubtitle),
      ),
    };
  }
}

/// Tema: Ikuti sistem / Terang / Gelap, kept on this device only.
class const _ThemeRow() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeControllerProvider.select((s) => s.value ?? ThemeMode.system));
    String label(ThemeMode m) => switch (m) {
      ThemeMode.system => l10n.settingsThemeSystem,
      ThemeMode.light => l10n.settingsThemeLight,
      ThemeMode.dark => l10n.settingsThemeDark,
    };

    return SettingsRow.navigation(
      label: l10n.settingsTheme,
      value: label(mode),
      onTap: () async {
        final picked = await _pick(
          context,
          title: l10n.settingsTheme,
          selected: mode,
          options: [for (final m in ThemeMode.values) (value: m, label: label(m))],
        );
        if (picked != null && picked != mode) {
          await ref.read(themeModeControllerProvider.notifier).set(picked);
        }
      },
    );
  }
}

/// Bahasa: saved on the account, then applied to the app.
class const _LanguageRow() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final code = ref.watch(localeControllerProvider.select((s) => s.value?.languageCode ?? 'id'));
    final loaded = ref.watch(settingsControllerProvider.select((s) => s.hasValue));
    final options = [
      (value: 'id', label: l10n.settingsLanguageId),
      (value: 'en', label: l10n.settingsLanguageEn),
    ];

    return SettingsRow.navigation(
      label: l10n.settingsLanguage,
      value: options.firstWhere((o) => o.value == code, orElse: () => options.first).label,
      onTap: () async {
        if (!loaded) return;
        final picked = await _pick(context, title: l10n.settingsLanguage, selected: code, options: options);
        if (picked == null || picked == code || !context.mounted) return;
        final failure = await ref.read(settingsControllerProvider.notifier).setLanguage(picked);
        if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
      },
    );
  }
}

class const _ClearCacheRow() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsRow.navigation(
      icon: AppIcons.image,
      label: l10n.settingsClearCache,
      onTap: () async {
        final failure = await ref.read(settingsControllerProvider.notifier).clearImageCache();
        if (!context.mounted) return;
        showAppToast(context, failure?.displayMessage ?? l10n.settingsCacheCleared);
      },
    );
  }
}

typedef _Option<T> = ({T value, String label});

/// A sheet with one row per option and a check on [selected]; resolves to
/// the tapped value, or null when dismissed.
Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<_Option<T>> options,
}) => showAppSheet<T>(
  context,
  builder: (context) => AppSheetBody(
    title: title,
    child: SettingsGroup(
      children: [
        for (final option in options)
          _ChoiceRow(
            label: option.label,
            selected: option.value == selected,
            onTap: () => Navigator.of(context).pop(option.value),
          ),
      ],
    ),
  ),
);

class const _ChoiceRow({
  required final String label,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      shape: const RoundedRectangleBorder(),
      scale: false,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.settingsRowH),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: t.bodyLg.copyWith(color: c.textPrimary)),
              ),
              if (selected) AppIcon(AppIcons.check, size: AppSizes.iconLg, color: c.paid.fg),
            ],
          ),
        ),
      ),
    );
  }
}
