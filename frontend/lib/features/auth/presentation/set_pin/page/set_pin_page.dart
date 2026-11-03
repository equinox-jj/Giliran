import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../shared/widgets/auth_scaffold.dart';
import '../../shared/widgets/pin_entry.dart';
import '../controllers/set_pin_controller.dart';

class const SetPinPage({super.key}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState() extends ConsumerState<SetPinPage> {
  final _pin = PinPadController();

  @override
  void initState() {
    super.initState();
    // A new step, or a rejected PIN, starts the pad empty. A saved PIN keeps
    // the dots filled under the spinner until the guard moves on.
    ref.listenManual(setPinControllerProvider, (previous, next) {
      if (next.done) return;
      if (previous?.firstPin != next.firstPin || next.failure != null) {
        _pin.clear();
      }
    });

    _pin.addListener(_onTyping);
  }

  /// The first digit of a new entry clears the last error.
  void _onTyping() {
    if (_pin.value.isNotEmpty) ref.read(setPinControllerProvider.notifier).clearFailure();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The step decides the back button; the error and busy state are read by
    // [_Entry] so they rebuild only the pad.
    final confirming = ref.watch(setPinControllerProvider.select((s) => s.firstPin != null));

    return AuthScaffold(
      step: confirming ? 'Langkah 2 dari 2' : 'Langkah 1 dari 2',
      showBack: confirming,
      pinPad: true,
      topPadding: 0,
      onBack: confirming ? () => ref.read(setPinControllerProvider.notifier).restart() : null,
      body: _Entry(controller: _pin, confirming: confirming),
    );
  }
}

class const _Entry({
  required final PinPadController controller,
  required final bool confirming,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:failure, :checking) = ref.watch(
      setPinControllerProvider.select((s) => (failure: s.failure, checking: s.submitting || s.done)),
    );

    return PinEntry(
      headline: confirming ? 'Ulangi **PIN**' : 'Buat **PIN 6 digit**',
      caption: confirming ? 'Masukkan PIN yang sama sekali lagi.' : 'Dipakai untuk membuka Giliran di HP ini.',
      hint: confirming ? null : 'Hindari angka berurutan atau sama semua, seperti 123456.',
      error: setPinErrorMessage(failure),
      controller: controller,
      checking: checking,
      onCompleted: ref.read(setPinControllerProvider.notifier).enter,
    );
  }
}

String? setPinErrorMessage(Failure? failure) {
  if (failure == null) return null;
  if (failure case ValidationFailure(:final fieldErrors)) {
    final codes = {for (final e in fieldErrors) e.code};
    if (codes.contains('pin_too_weak')) {
      return 'Hindari angka berurutan atau sama semua.';
    }
    if (codes.contains('mismatch')) return 'PIN tidak sama. Ulangi dari awal.';
  }

  return failure.displayMessage;
}
