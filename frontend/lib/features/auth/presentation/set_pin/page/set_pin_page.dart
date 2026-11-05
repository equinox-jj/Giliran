import '../../../../../core/l10n/l10n.dart';

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
      step: context.l10n.authStepOf(confirming ? 2 : 1, 2),
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
      headline: confirming ? context.l10n.authSetPinConfirmHeadline : context.l10n.authSetPinHeadline,
      caption: confirming ? context.l10n.authRepeatPinCaption : context.l10n.authSetPinCaption,
      hint: confirming ? null : context.l10n.authPinWeakHint,
      error: setPinErrorMessage(context.l10n, failure),
      controller: controller,
      checking: checking,
      onCompleted: (pin) => ref.read(setPinControllerProvider.notifier).enter(pin),
    );
  }
}

String? setPinErrorMessage(AppLocalizations l10n, Failure? failure) {
  if (failure == null) return null;
  if (failure case ValidationFailure(:final fieldErrors)) {
    final codes = {for (final e in fieldErrors) e.code};
    if (codes.contains('pin_too_weak')) {
      return l10n.authPinTooWeak;
    }
    if (codes.contains('mismatch')) return l10n.authPinMismatch;
  }

  return failure.displayMessage(l10n);
}
