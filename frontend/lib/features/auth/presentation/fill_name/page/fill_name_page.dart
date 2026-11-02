import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../controllers/fill_name_controller.dart';

/// S05 Fill in name: the name other members see and an optional WhatsApp
/// number. Saving moves the session on, and the guard opens S06.
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

/// "Lanjut", on once the name has at least two characters.
class const _NextButton({
  required final TextEditingController name,
  required final VoidCallback onSubmit,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(
      fillNameControllerProvider.select((s) => s.isLoading),
    );

    return ValueListenableBuilder(
      valueListenable: name,
      builder: (context, value, _) => AppButton(
        label: 'Lanjut',
        block: true,
        loading: loading,
        onPressed: value.text.trim().length >= FillNamePage.minName ? onSubmit : null,
      ),
    );
  }
}
