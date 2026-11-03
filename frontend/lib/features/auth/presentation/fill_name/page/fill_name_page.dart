import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/photo_source.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../profile/presentation/shared/controllers/avatar_controller.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../controllers/fill_name_controller.dart';

class const FillNamePage({super.key}) extends ConsumerStatefulWidget {
  static const minName = 2;
  static const maxName = 50;

  @override
  ConsumerState<FillNamePage> createState() => _FillNamePageState();
}

class _FillNamePageState() extends ConsumerState<FillNamePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _phoneError = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _phoneError.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final local = _phone.text.trim();
    final phone = local.isEmpty ? null : PhoneFormatter.normalize(local);
    if (local.isNotEmpty && (phone == null || !PhoneFormatter.isValid(phone))) {
      _phoneError.value = 'Nomor WhatsApp belum benar';
      return;
    }
    _phoneError.value = null;

    final saved = await ref.read(fillNameControllerProvider.notifier).submit(name: _name.text, phone: phone);
    if (!mounted || saved) return;
    final failure = ref.read(fillNameControllerProvider).error;
    if (failure is Failure && failure is! ValidationFailure) {
      showAppToast(context, failure.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      bottomPadding: AppSpace.s8,
      body: _Form(name: _name, phone: _phone, phoneError: _phoneError),
      bottom: _NextButton(name: _name, onSubmit: _submit),
    );
  }
}

class const _Form({
  required final TextEditingController name,
  required final TextEditingController phone,
  required final ValueNotifier<String?> phoneError,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final failure = ref.watch(
      fillNameControllerProvider.select((s) => s.error),
    );
    final serverError = failure is Failure ? failure : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HeadlineText('Siapa **nama kamu**?'),
        const SizedBox(height: AppSpace.s2),
        Text(
          'Nama ini dilihat anggota arisan lain.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.s6),
        const Center(child: _AvatarSection()),
        const SizedBox(height: AppSpace.s6),
        ValueListenableBuilder(
          valueListenable: name,
          builder: (context, value, _) => _NameField(
            controller: name,
            length: value.text.characters.length,
            errorText: serverError?.fieldMessage('name'),
          ),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder(
          valueListenable: phoneError,
          builder: (context, error, _) => PhoneField(
            controller: phone,
            helper: 'Hanya untuk pengingat bayar. Bukan untuk masuk.',
            helperIcon: AppIcons.bellSimple,
            errorText: error ?? serverError?.fieldMessage('phone'),
            onChanged: (_) => phoneError.value = null,
          ),
        ),
      ],
    );
  }
}

/// The optional photo (§8.21 in circle form). It uploads as soon as it is
/// picked; a failed upload shows "Coba lagi" and never blocks "Lanjut".
class const _AvatarSection() extends ConsumerWidget {
  Future<void> _change(BuildContext context, WidgetRef ref, {required bool hasPhoto}) async {
    final action = await showAvatarSourceSheet(context, canRemove: hasPhoto);
    if (action == null || !context.mounted) return;
    final controller = ref.read(avatarControllerProvider.notifier);
    switch (action) {
      case AvatarSheetAction.camera || AvatarSheetAction.gallery:
        final source = action == AvatarSheetAction.camera ? PhotoSource.camera : PhotoSource.gallery;
        final allowed = await controller.pick(source);
        if (!allowed && context.mounted) {
          showAppToast(
            context,
            source == PhotoSource.camera ? 'Izinkan akses kamera di Pengaturan.' : 'Izinkan akses foto di Pengaturan.',
          );
        }
      case AvatarSheetAction.remove:
        final failure = await controller.remove();
        if (failure != null && context.mounted) {
          showAppToast(context, failure.displayMessage);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarControllerProvider);

    return AvatarPicker(
      localPath: avatar.localPath,
      imageUrl: avatar.imageUrl,
      progress: avatar.progress,
      errorText: avatar.failure?.displayMessage,
      done: avatar.done,
      onTap: () => _change(context, ref, hasPhoto: avatar.hasPhoto),
      onRetry: ref.read(avatarControllerProvider.notifier).retry,
    );
  }
}

/// "Nama" with the "22/50" count under it.
class const _NameField({
  required final TextEditingController controller,
  required final int length,
  required final String? errorText,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'Nama',
      hint: 'Nama panggilan atau lengkap',
      helper: 'Pakai nama yang dikenal anggota.',
      counter: '$length/${FillNamePage.maxName}',
      errorText: errorText,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      inputFormatters: [
        LengthLimitingTextInputFormatter(FillNamePage.maxName),
      ],
    );
  }
}

/// "Lanjut", on once the name has at least two characters and no photo is
/// still uploading.
class const _NextButton({
  required final TextEditingController name,
  required final VoidCallback onSubmit,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(
      fillNameControllerProvider.select((s) => s.isLoading),
    );
    final uploading = ref.watch(
      avatarControllerProvider.select((s) => s.uploading),
    );

    return ValueListenableBuilder(
      valueListenable: name,
      builder: (context, value, _) => AppButton(
        label: 'Lanjut',
        block: true,
        loading: loading,
        disabledReason: uploading ? 'Tunggu foto selesai diunggah' : null,
        onPressed: value.text.trim().length >= FillNamePage.minName && !uploading ? onSubmit : null,
      ),
    );
  }
}
