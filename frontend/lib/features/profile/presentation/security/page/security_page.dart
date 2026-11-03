import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../auth/presentation/shared/controllers/biometric_controller.dart';
import '../../../../auth/presentation/shared/widgets/biometric_copy.dart';
import '../../../domain/entity/session.dart';
import '../controllers/sessions_controller.dart';

/// Security (S44): PIN, biometric unlock, auto-lock, email, and the
/// signed-in devices.
class const SecurityPage({
  super.key,
  required final VoidCallback onChangePin,
  required final VoidCallback onChangeEmail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = context.screenMargin;

    return Scaffold(
      appBar: AppTopBar(title: l10n.securityTitle),
      body: MaxWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, 0),
              sliver: SliverToBoxAdapter(
                child: SettingsGroup(
                  children: [
                    SettingsRow.navigation(
                      icon: AppIcons.lockSimple,
                      label: l10n.securityChangePin,
                      onTap: onChangePin,
                    ),
                    const _BiometricRow(),
                    SettingsRow.info(
                      icon: AppIcons.hourglassMedium,
                      label: l10n.securityAutoLock,
                      value: l10n.securityAutoLockValue,
                    ),
                    SettingsRow.navigation(
                      icon: AppIcons.envelopeSimple,
                      label: l10n.securityChangeEmail,
                      onTap: onChangeEmail,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margin, 0, margin, AppSpace.s8),
              sliver: const _Devices(),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Buka dengan {biometric}"; hidden when the device has no biometrics.
class const _BiometricRow() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(biometricControllerProvider.select((s) => s.value?.kind));
    final enabled = ref.watch(biometricControllerProvider.select((s) => s.value?.enabled ?? false));
    if (kind == null) return const SizedBox.shrink();

    return SettingsRow.toggle(
      icon: kind.icon,
      label: context.l10n.securityBiometric(kind.nameOn(Theme.of(context).platform)),
      toggleValue: enabled,
      onToggle: (value) async {
        final failure = await ref.read(biometricControllerProvider.notifier).setEnabled(value);
        if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
      },
    );
  }
}

/// "Perangkat aktif": loading, error with retry, or the session rows and the
/// "sign out all others" row.
class const _Devices() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsControllerProvider);
    final header = SliverToBoxAdapter(child: _Header(label: l10n.securityDevices));

    final Widget body = switch (sessions) {
      AsyncData(:final value) => _SessionList(sessions: value),
      AsyncError() => SliverToBoxAdapter(
        child: AppBanner(
          message: l10n.securityDevicesFailed,
          variant: AppBannerVariant.error,
          actionLabel: l10n.commonRetry,
          onAction: ref.read(sessionsControllerProvider.notifier).reload,
        ),
      ),
      _ => const SliverToBoxAdapter(child: _LoadingRows()),
    };

    return SliverMainAxisGroup(slivers: [header, body]);
  }
}

class const _Header({required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.s4, bottom: AppSpace.s2),
      child: Semantics(
        header: true,
        child: Text(label, style: t.caption.copyWith(color: c.textTertiary)),
      ),
    );
  }
}

class const _SessionList({required final List<Session> sessions}) extends ConsumerWidget {
  Future<void> _revoke(BuildContext context, WidgetRef ref, String id) async {
    final failure = await ref.read(sessionsControllerProvider.notifier).revoke(id);
    if (failure != null && context.mounted) showAppToast(context, failure.displayMessage);
  }

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showAppDialog(
      context,
      title: l10n.securitySignOutOthersTitle,
      message: l10n.securitySignOutOthersMessage,
      confirmLabel: l10n.sessionSignOut,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref.read(sessionsControllerProvider.notifier).revokeOthers();
    if (!context.mounted) return;
    showAppToast(
      context,
      switch (result) {
        Left(:final value) => value.displayMessage,
        Right(:final value) => l10n.securitySignOutOthersDone(value),
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hasOthers = sessions.any((s) => s.isCurrent != true);

    return SliverMainAxisGroup(
      slivers: [
        DecoratedSliver(
          decoration: ShapeDecoration(
            color: c.surface,
            shape: AppShapes.squircle(AppRadius.md),
          ),
          sliver: SliverList.separated(
            itemCount: sessions.length,
            separatorBuilder: (context, _) => Padding(
              padding: const EdgeInsets.only(left: AppSpace.s4),
              child: Divider(color: c.hairline),
            ),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final id = session.id;
              return SessionRow(
                key: ValueKey(id),
                deviceName: session.deviceName,
                platform: session.devicePlatform,
                lastActiveAt: session.lastActiveAt,
                current: session.isCurrent == true,
                onSignOut: id == null ? null : () => _revoke(context, ref, id),
              );
            },
          ),
        ),
        if (hasOthers)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpace.s6),
            sliver: SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  SettingsRow.destructive(
                    icon: AppIcons.signOut,
                    label: context.l10n.securitySignOutOthers,
                    onTap: () => _revokeOthers(context, ref),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Two placeholder rows while the sessions load.
class const _LoadingRows() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Skeleton(height: AppSizes.rowH),
      SizedBox(height: AppSpace.s2),
      Skeleton(height: AppSizes.rowH),
    ],
  );
}
