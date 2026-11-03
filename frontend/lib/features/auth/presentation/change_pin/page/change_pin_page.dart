import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../set_pin/page/set_pin_page.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/pin_entry.dart';
import '../../shared/widgets/step_pills.dart';
import '../controllers/change_pin_controller.dart';

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

    // The close button leaves the flow; the system back steps back.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AuthScaffold(
        step: 'Ubah PIN',
        stepColor: context.colors.textPrimary,
        modal: true,
        pinPad: true,
        onBack: widget.onDone,
        body: _Entry(controller: _pin, step: step, onForgotPin: widget.onForgotPin),
      ),
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
    final pills = StepPills(
      labels: const ['PIN lama', 'PIN baru', 'Ulangi'],
      current: step.index,
      alignment: WrapAlignment.center,
    );

    return switch (step) {
      ChangePinStep.current => CurrentPinEntry(
        top: pills,
        headingTop: AppSpace.s8,
        dotsGap: 36,
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
        top: pills,
        headingTop: AppSpace.s8,
        dotsGap: 36,
        headline: 'Masukkan **PIN baru**',
        caption: 'Perangkat lain tetap masuk seperti biasa.',
        error: setPinErrorMessage(failure),
        controller: controller,
        onCompleted: notifier.enter,
      ),
      ChangePinStep.confirm => PinEntry(
        top: pills,
        headingTop: AppSpace.s8,
        dotsGap: 36,
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
