import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../shared/widgets/widgets.dart';
import '../../set_pin/page/set_pin_page.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/pin_entry.dart';
import '../controllers/change_pin_controller.dart';

/// S45 Change PIN: the current PIN, then the new PIN twice on the S06 pad.
/// Other sessions stay signed in (FR-AUTH-04). [onDone] closes the flow
/// after the toast, and [onForgotPin] opens S09 from a wrong or locked PIN.
class const ChangePinPage({super.key, required final VoidCallback onDone, required final VoidCallback onForgotPin})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState() extends ConsumerState<ChangePinPage> {
  final _pin = PinPadController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(changePinControllerProvider, _onState);
    _pin.addListener(_onTyping);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _onState(ChangePinState? previous, ChangePinState next) {
    if (next.done && previous?.done != true) {
      showAppToast(context, 'PIN berhasil diganti.');
      widget.onDone();
      return;
    }
    // A new step, or a rejected entry, starts the pad empty.
    if (previous?.step != next.step || (next.failure != null && next.failure != previous?.failure)) {
      _pin.clear();
    }
  }

  /// The first digit of a new entry clears the last error.
  void _onTyping() {
    if (_pin.value.isNotEmpty) ref.read(changePinControllerProvider.notifier).clearFailure();
  }

  void _back() {
    if (!ref.read(changePinControllerProvider.notifier).back()) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(changePinControllerProvider.select((s) => s.step));

    return AuthScaffold(
      step: 'Langkah ${step.index + 1} dari ${ChangePinStep.values.length}',
      pinPad: true,
      onBack: _back,
      body: _Entry(controller: _pin, step: step, onForgotPin: widget.onForgotPin),
    );
  }
}

/// The pad for [step]: the current PIN with the lock rules, or the new PIN.
class const _Entry({
  required final PinPadController controller,
  required final ChangePinStep step,
  required final VoidCallback onForgotPin,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:failure, :checking, :lockedUntil) = ref.watch(
      changePinControllerProvider.select(
        (s) => (failure: s.failure, checking: s.submitting || s.done, lockedUntil: s.lockedUntil),
      ),
    );
    final notifier = ref.read(changePinControllerProvider.notifier);

    return switch (step) {
      ChangePinStep.current => CurrentPinEntry(
        headline: 'Masukkan **PIN lama**',
        caption: 'Pastikan ini kamu sebelum mengganti PIN.',
        error: wrongPinMessage(failure),
        controller: controller,
        lockedUntil: lockedUntil,
        onLockFinished: notifier.lockFinished,
        onForgotPin: onForgotPin,
        onCompleted: notifier.enter,
      ),
      ChangePinStep.newPin => PinEntry(
        headline: 'Buat **PIN baru**',
        caption: 'PIN lama tidak bisa dipakai lagi.',
        hint: 'Hindari angka berurutan atau sama semua, seperti 123456.',
        error: setPinErrorMessage(failure),
        controller: controller,
        onCompleted: notifier.enter,
      ),
      ChangePinStep.confirm => PinEntry(
        headline: 'Ulangi **PIN baru**',
        caption: 'Masukkan PIN yang sama sekali lagi.',
        error: setPinErrorMessage(failure),
        controller: controller,
        checking: checking,
        onCompleted: notifier.enter,
      ),
    };
  }
}
