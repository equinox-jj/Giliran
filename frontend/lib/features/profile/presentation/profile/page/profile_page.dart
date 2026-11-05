import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../auth/domain/entities/auth_status.dart';
import '../../../../auth/presentation/shared/controllers/auth_session_controller.dart';
import '../../../domain/entity/profile.dart';

/// The Profil tab (S42): who is signed in, links to Security and Settings,
/// help, about, and signing out.
class const ProfilePage({
  super.key,
  required final VoidCallback onEdit,
  required final VoidCallback onSecurity,
  required final VoidCallback onSettings,
}) extends StatelessWidget {
  static final privacyUrl = Uri.parse('https://giliran.monai.my.id/privacy');
  static final contactUrl = Uri.parse('mailto:joejoe100799@gmail.com');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = context.screenMargin;

    return Scaffold(
      appBar: AppTopBar(title: l10n.profileTitle, showBack: false),
      body: MaxWidth(
        child: ListView(
          // The shell's floating bar overlays the body (extendBody), so the
          // list ends above it on compact windows.
          padding: EdgeInsets.fromLTRB(
            margin,
            AppSpace.s2,
            margin,
            context.isCompact ? AppBottomNavBar.contentInset(context) : AppSpace.s8,
          ),
          children: [
            const _Header(),
            const SizedBox(height: AppSpace.s4),
            Center(
              child: AppButton.secondary(
                label: l10n.profileEditButton,
                size: AppButtonSize.small,
                icon: AppIcons.pencilSimple,
                onPressed: onEdit,
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            SettingsGroup(
              header: l10n.profileGroupAccount,
              children: [
                SettingsRow.navigation(
                  icon: AppIcons.shieldCheck,
                  label: l10n.profileSecurity,
                  onTap: onSecurity,
                ),
                SettingsRow.navigation(
                  icon: AppIcons.gear,
                  label: l10n.profileSettings,
                  onTap: onSettings,
                ),
              ],
            ),
            const _HelpGroup(),
            const _AboutGroup(),
            const _LogoutGroup(),
          ],
        ),
      ),
    );
  }
}

/// The signed-in user from the session, or null while it is not open.
ProfileData? _sessionUser(AsyncValue<AuthStatus> status) => switch (status.value) {
  AuthUnlocked(:final user) || AuthLocked(:final user) => user,
  _ => null,
};

/// Avatar 80, name, email and the WhatsApp number when set.
class const _Header() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final user = ref.watch(authSessionControllerProvider.select(_sessionUser));
    final name = user?.name ?? '';
    final phone = user?.phone;

    return Column(
      children: [
        AppAvatar(
          name: name.isEmpty ? '?' : name,
          imageUrl: user?.avatarUrl,
          size: AppSizes.avatarXl,
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          name,
          style: t.titleLg.copyWith(color: c.textPrimary),
          textAlign: TextAlign.center,
        ),
        if (user?.email case final email?) ...[
          const SizedBox(height: AppSpace.s1),
          Text(
            email,
            style: t.body.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (phone != null && phone.isNotEmpty)
          Text(
            PhoneFormatter.display(phone),
            style: t.body.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class const _HelpGroup() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsGroup(
      header: l10n.profileGroupHelp,
      children: [
        SettingsRow.navigation(
          icon: AppIcons.shuffle,
          label: l10n.profileHelpDraw,
          onTap: () => showHelpSheet(
            context,
            title: l10n.profileHelpDraw,
            paragraphs: [l10n.profileHelpDrawBody1, l10n.profileHelpDrawBody2],
          ),
        ),
        SettingsRow.navigation(
          icon: AppIcons.handCoins,
          label: l10n.profileHelpMoney,
          onTap: () => showHelpSheet(
            context,
            title: l10n.profileHelpMoney,
            paragraphs: [l10n.profileHelpMoneyBody1, l10n.profileHelpMoneyBody2],
          ),
        ),
        SettingsRow.navigation(
          icon: AppIcons.envelopeSimple,
          label: l10n.profileHelpContact,
          onTap: () => _open(context, ProfilePage.contactUrl),
        ),
      ],
    );
  }
}

class const _AboutGroup() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsGroup(
      header: l10n.profileGroupAbout,
      children: [
        SettingsRow.navigation(
          icon: AppIcons.lockSimple,
          label: l10n.profilePrivacy,
          onTap: () => _open(context, ProfilePage.privacyUrl),
        ),
        SettingsRow.navigation(
          icon: AppIcons.scroll,
          label: l10n.profileTerms,
          // The privacy page carries the terms too (PRD privacy section).
          onTap: () => _open(context, ProfilePage.privacyUrl),
        ),
        SettingsRow.navigation(
          icon: AppIcons.sealCheck,
          label: l10n.profileLicenses,
          onTap: () => showLicensePage(context: context, applicationName: l10n.appName),
        ),
        const _VersionRow(),
      ],
    );
  }
}

/// "Versi app 1.0.0 (1)", read once from the platform.
class const _VersionRow() extends StatefulWidget {
  @override
  State<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState() extends State<_VersionRow> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    } on Exception {
      // The row stays empty; the version is informational only.
    }
  }

  @override
  Widget build(BuildContext context) => SettingsRow.info(
    icon: AppIcons.info,
    label: context.l10n.profileVersion,
    value: _version,
  );
}

class const _LogoutGroup() extends ConsumerWidget {
  /// Confirms, then signs out. The router guard sends the user to Welcome
  /// once the session is signed out.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showAppDialog(
      context,
      title: l10n.profileLogoutTitle,
      message: l10n.profileLogoutMessage,
      confirmLabel: l10n.profileLogout,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    final failure = await ref.read(authSessionControllerProvider.notifier).logout();
    if (failure != null && context.mounted) showAppToast(context, failure.displayMessage(context.l10n));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsGroup(
    children: [
      SettingsRow.destructive(
        icon: AppIcons.signOut,
        label: context.l10n.profileLogout,
        onTap: () => _logout(context, ref),
      ),
    ],
  );
}

Future<void> _open(BuildContext context, Uri url) async {
  final message = context.l10n.linkOpenFailed;
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Exception {
    opened = false;
  }
  if (!opened && context.mounted) showAppToast(context, message);
}
