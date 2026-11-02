import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/auth_status.dart';
import '../../shared/controllers/auth_session_controller.dart';
import '../../shared/controllers/biometric_controller.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/biometric_copy.dart';
import '../../shared/widgets/pin_entry.dart';
import '../controllers/pin_lock_controller.dart';

/// S08 PIN lock: greets the user and opens the session with the PIN or
/// biometric. Unlocking moves the session on and the guard leaves.
/// [onForgotPin] opens S09 with the account's email.
class const PinLockPage({super.key, required final ValueChanged<String?> onForgotPin}) extends ConsumerStatefulWidget {
  /// The reason shown in the system biometric prompt.
  static const biometricReason = 'Buka Giliran';

  /// "Sisa {n} percobaan" shows from this many wrong PINs on.
  static const showAttemptsAfter = 3;

  @override
  ConsumerState<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState() extends ConsumerState<PinLockPage> {
  final _pin = PinPadController();
  final _wrong = ValueNotifier(0);
  final _lockedUntil = ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    ref.listenManual(pinLockControllerProvider, _onState);
    _pin.addListener(_onTyping);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoBiometric());
  }

  @override
  void dispose() {
    _pin.dispose();
    _wrong.dispose();
    _lockedUntil.dispose();
    super.dispose();
  }

  void _onState(PinLockState? previous, PinLockState next) {
    final failure = next.failure;
    if (failure == null || failure == previous?.failure) return;
    _pin.clear();
    switch (failure.apiCode) {
      case ApiErrorCode.pinInvalid:
        _wrong.value++;
      case ApiErrorCode.pinLocked:
        _lockedUntil.value = next.lockedUntil;
      default:
        showAppToast(context, failure.displayMessage);
    }
  }

  /// The first digit of a new entry clears "PIN salah".
  void _onTyping() {
    if (_pin.value.isNotEmpty) ref.read(pinLockControllerProvider.notifier).clearFailure();
  }

  /// Prompts the biometric once when the lock opens, if it is on.
  Future<void> _autoBiometric() async {
    if (!mounted) return;
    try {
      final status = await ref.read(biometricControllerProvider.future);
      if (!mounted || status.enabled != true || status.kind == null) return;
      await ref.read(pinLockControllerProvider.notifier).unlockWithBiometric(PinLockPage.biometricReason);
    } on Failure {
      // No biometric status: the PIN pad stays.
    }
  }

  Future<void> _logout() async {
    final confirmed = await showAppDialog(
      context,
      title: 'Keluar dari Giliran?',
      message: 'Kamu perlu masuk lagi dengan email di perangkat ini.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(pinLockControllerProvider.notifier).logout();
    if (failure != null && mounted) showAppToast(context, failure.displayMessage);
  }

  void _forgotPin() {
    final status = ref.read(authSessionControllerProvider).value;
    widget.onForgotPin(status is AuthLocked ? status.user?.email : null);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showTopBar: false,
      pinPad: true,
      body: _LockPad(
        controller: _pin,
        wrong: _wrong,
        lockedUntil: _lockedUntil,
        footer: _Links(onForgotPin: _forgotPin, onLogout: _logout),
      ),
    );
  }
}

/// "Lupa PIN?" and "Bukan kamu? Keluar" under the pad.
class const _Links({required final VoidCallback onForgotPin, required final VoidCallback onLogout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: AppSpace.s5),
      AppButton.link(label: 'Lupa PIN?', size: AppButtonSize.small, onPressed: onForgotPin),
      const SizedBox(height: AppSpace.s1),
      _LogoutButton(onPressed: onLogout),
    ],
  );
}

/// "Bukan kamu? Keluar" in `text.secondary`, medium weight.
class const _LogoutButton({required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    return Pressable(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Center(
            widthFactor: 1,
            child: Text(
              'Bukan kamu? Keluar',
              style: t.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar 56, "Halo, {name}" and the caption, with the space around them.
class const _Greeting() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final user = ref.watch(
      authSessionControllerProvider.select(
        (s) => switch (s.value) {
          AuthLocked(:final user) || AuthUnlocked(:final user) => user,
          _ => null,
        },
      ),
    );
    final name = user?.name?.trim() ?? '';
    final firstName = name.split(RegExp(r'\s+')).first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpace.s6),
        AppAvatar(
          name: name.isEmpty ? '?' : name,
          imageUrl: user?.avatarUrl,
          size: AppSizes.avatarLg,
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          firstName.isEmpty ? 'Halo' : 'Halo, $firstName',
          textAlign: TextAlign.center,
          style: t.title.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          'Masukkan PIN untuk membuka Giliran',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: AppSpace.s8),
      ],
    );
  }
}

/// The greeting and the PIN pad with the biometric key, or the lock
/// countdown after `pin_locked`, with the [footer] links under either.
class const _LockPad({
  required final PinPadController controller,
  required final ValueNotifier<int> wrong,
  required final ValueNotifier<DateTime?> lockedUntil,
  required final Widget footer,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pinLockControllerProvider);
    final biometric = ref.watch(biometricControllerProvider).value;
    final kind = biometric?.kind;
    final notifier = ref.read(pinLockControllerProvider.notifier);
    final wrongPin = state.failure?.apiCode == ApiErrorCode.pinInvalid;

    return ValueListenableBuilder(
      valueListenable: lockedUntil,
      builder: (context, until, _) {
        if (until != null) {
          return PinCountdownLayout(
            header: const _Greeting(),
            countdown: CountdownText.lock(
              until: until,
              caption: 'Terlalu banyak PIN salah. Coba lagi setelah waktu habis.',
              onFinished: () => lockedUntil.value = null,
            ),
            footer: footer,
          );
        }
        final name = kind?.nameOn(Theme.of(context).platform);
        return PinPad(
          controller: controller,
          error: wrongPin,
          checking: state.submitting,
          expand: true,
          header: const _Greeting(),
          footer: footer,
          onCompleted: notifier.verify,
          onBiometric: biometric?.enabled == true && kind != null
              ? () => notifier.unlockWithBiometric(PinLockPage.biometricReason)
              : null,
          biometricIcon: kind?.icon ?? AppIcons.fingerprint,
          biometricLabel: 'Buka dengan ${name ?? 'sidik jari'}',
          belowDots: ValueListenableBuilder(
            valueListenable: wrong,
            builder: (context, count, _) => PinErrorLine(
              message: !wrongPin
                  ? null
                  : count >= PinLockPage.showAttemptsAfter && state.attemptsRemaining != null
                  ? 'PIN salah. Sisa ${state.attemptsRemaining} percobaan.'
                  : 'PIN salah.',
            ),
          ),
        );
      },
    );
  }
}
