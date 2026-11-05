import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/photo_source.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../auth/domain/entities/auth_status.dart';
import '../../../../auth/presentation/shared/controllers/auth_session_controller.dart';
import '../../../../auth/presentation/shared/widgets/auth_scaffold.dart';
import '../../shared/controllers/avatar_controller.dart';
import '../controllers/edit_profile_controller.dart';

/// Edit profile: photo, name, the optional WhatsApp number, and the
/// read-only email with a link to Change email.
class const EditProfilePage({
  super.key,
  required final VoidCallback onChangeEmail,

  /// Called after a successful save.
  required final VoidCallback onDone,
}) extends ConsumerStatefulWidget {
  static const minName = 2;
  static const maxName = 50;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState() extends ConsumerState<EditProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nameError = ValueNotifier<String?>(null);
  final _phoneError = ValueNotifier<String?>(null);
  late final Listenable _fields = Listenable.merge([_name, _phone]);

  String _initialName = '';
  String? _initialPhone;
  String? _email;

  @override
  void initState() {
    super.initState();
    final user = switch (ref.read(authSessionControllerProvider).value) {
      AuthUnlocked(:final user) || AuthLocked(:final user) => user,
      _ => null,
    };
    _initialName = user?.name ?? '';
    _initialPhone = (user?.phone?.isEmpty ?? true) ? null : user?.phone;
    _email = user?.email;
    _name.text = _initialName;
    _phone.text = switch (_initialPhone) {
      final phone? => PhoneFormatter.localPart(phone),
      null => '',
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameError.dispose();
    _phoneError.dispose();
    super.dispose();
  }

  /// The phone as typed, in E.164, or null when the field is empty.
  String? get _typedPhone {
    final local = _phone.text.trim();
    return local.isEmpty ? null : PhoneFormatter.normalize(local);
  }

  bool get _changed => _name.text.trim() != _initialName.trim() || _typedPhone != _initialPhone;

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final nameLength = name.characters.length;
    final phone = _typedPhone;

    _nameError.value = nameLength < EditProfilePage.minName || nameLength > EditProfilePage.maxName
        ? l10n.editProfileNameError
        : null;
    _phoneError.value = phone != null && !PhoneFormatter.isValid(phone) ? l10n.editProfilePhoneError : null;
    if (_nameError.value != null || _phoneError.value != null) return;

    final nameChanged = name != _initialName.trim();
    final phoneChanged = phone != _initialPhone;
    final saved = await ref
        .read(editProfileControllerProvider.notifier)
        .save(
          name: nameChanged ? name : null,
          phone: phoneChanged ? phone : null,
          clearPhone: phoneChanged && phone == null,
        );
    if (!mounted) return;
    if (saved) {
      showAppToast(context, l10n.editProfileSaved);
      widget.onDone();
      return;
    }
    final failure = ref.read(editProfileControllerProvider).error;
    if (failure is Failure && failure is! ValidationFailure) {
      showAppToast(context, failure.displayMessage(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.l10n.editProfileTitle,
      bottomPadding: AppSpace.s8,
      body: _Form(
        name: _name,
        phone: _phone,
        nameError: _nameError,
        phoneError: _phoneError,
        email: _email,
        onChangeEmail: widget.onChangeEmail,
      ),
      bottom: ListenableBuilder(
        listenable: _fields,
        builder: (context, _) => _SaveButton(
          changed: _changed,
          onSave: _save,
        ),
      ),
    );
  }
}

class const _Form({
  required final TextEditingController name,
  required final TextEditingController phone,
  required final ValueNotifier<String?> nameError,
  required final ValueNotifier<String?> phoneError,
  required final String? email,
  required final VoidCallback onChangeEmail,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final failure = ref.watch(
      editProfileControllerProvider.select((s) => s.error),
    );
    final serverError = failure is Failure ? failure : null;
    void clearServerError() => ref.read(editProfileControllerProvider.notifier).clearError();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _AvatarSection()),
        const SizedBox(height: AppSpace.s6),
        ListenableBuilder(
          listenable: Listenable.merge([name, nameError]),
          builder: (context, _) => AppTextField(
            controller: name,
            label: l10n.editProfileName,
            hint: l10n.editProfileNameHint,
            counter: '${name.text.characters.length}/${EditProfilePage.maxName}',
            errorText: nameError.value ?? serverError?.fieldMessage('name'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [
              LengthLimitingTextInputFormatter(EditProfilePage.maxName),
            ],
            onChanged: (_) {
              nameError.value = null;
              clearServerError();
            },
          ),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder(
          valueListenable: phoneError,
          builder: (context, error, _) => PhoneField(
            controller: phone,
            label: l10n.editProfilePhoneLabel,
            labelHint: l10n.editProfileOptional,
            helper: l10n.editProfilePhoneHelper,
            helperIcon: AppIcons.bellSimple,
            errorText: error ?? serverError?.fieldMessage('phone'),
            onChanged: (_) {
              phoneError.value = null;
              clearServerError();
            },
          ),
        ),
        const SizedBox(height: AppSpace.s6),
        if (email != null) _EmailRow(email: email!, onChange: onChangeEmail),
      ],
    );
  }
}

/// Avatar 96 with the camera badge. A change uploads at once and refreshes
/// the session user, so it never waits for "Simpan".
class const _AvatarSection() extends ConsumerWidget {
  Future<void> _change(BuildContext context, WidgetRef ref, {required bool hasPhoto}) async {
    final l10n = context.l10n;
    final action = await showAvatarSourceSheet(context, canRemove: hasPhoto);
    if (action == null || !context.mounted) return;
    final controller = ref.read(avatarControllerProvider.notifier);
    final session = ref.read(authSessionControllerProvider.notifier);
    switch (action) {
      case AvatarSheetAction.camera || AvatarSheetAction.gallery:
        final source = action == AvatarSheetAction.camera ? PhotoSource.camera : PhotoSource.gallery;
        final allowed = await controller.pick(source);
        if (!allowed && context.mounted) {
          showAppToast(
            context,
            source == PhotoSource.camera ? l10n.avatarCameraDenied : l10n.avatarGalleryDenied,
          );
        }
      case AvatarSheetAction.remove:
        final failure = await controller.remove();
        if (failure != null && context.mounted) {
          showAppToast(context, failure.displayMessage(context.l10n));
          return;
        }
    }
    await session.refresh(unlocked: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarControllerProvider);

    return AvatarPicker(
      localPath: avatar.localPath,
      imageUrl: avatar.imageUrl,
      progress: avatar.progress,
      errorText: avatar.failure?.displayMessage(context.l10n),
      // The check badge only confirms a photo picked on this screen.
      done: avatar.done && avatar.localPath != null,
      size: AppSizes.avatarXxl,
      onTap: () => _change(context, ref, hasPhoto: avatar.hasPhoto),
      onRetry: ref.watch(avatarControllerProvider.notifier).retry,
    );
  }
}

/// Read-only email with the "Ubah" link to Change email.
class const _EmailRow({
  required final String email,
  required final VoidCallback onChange,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.editProfileEmail, style: t.label.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpace.s1),
              Text(email, style: t.bodyLg.copyWith(color: c.textPrimary)),
            ],
          ),
        ),
        AppButton.link(
          label: l10n.editProfileChangeEmail,
          semanticLabel: l10n.securityChangeEmail,
          onPressed: onChange,
        ),
      ],
    );
  }
}

/// "Simpan", on once a field changed and no photo is still uploading.
class const _SaveButton({
  required final bool changed,
  required final VoidCallback onSave,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(
      editProfileControllerProvider.select((s) => s.isLoading),
    );
    final uploading = ref.watch(
      avatarControllerProvider.select((s) => s.uploading),
    );

    return AppButton(
      label: context.l10n.editProfileSave,
      block: true,
      loading: loading,
      disabledReason: uploading ? context.l10n.editProfileWaitUpload : null,
      onPressed: changed && !uploading ? onSave : null,
    );
  }
}
