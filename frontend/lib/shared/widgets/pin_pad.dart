import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'dashed_border.dart';
import 'pressable.dart';
import 'shake.dart';

/// Holds the digits entered on a [PinPad]. Call [clear] after a wrong PIN or
/// between "Buat PIN" and "Ulangi PIN".
class PinPadController() extends ValueNotifier<String> {
  this : super('');

  void clear() => value = '';
}

/// Six PIN dots plus a 3×4 keypad of 72 px keys. The biometric key
/// (bottom-left) shows only when [onBiometric] is set (lock screen).
class const PinPad({
  super.key,
  required final PinPadController controller,
  required final ValueChanged<String> onCompleted,
  final int length = 6,

  /// Wrong PIN: dots turn bata and shake. The parent clears the controller.
  final bool error = false,
  final bool enabled = true,
  final VoidCallback? onBiometric,

  /// `AppIcons.fingerprint` on Android, `AppIcons.scanSmiley` for Face ID.
  final String biometricIcon = AppIcons.fingerprint,
  final String biometricLabel = 'Buka dengan sidik jari',
}) extends StatefulWidget {
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState() extends State<PinPad> {
  int _shakes = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
    if (widget.error && !old.error) _shakes++;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  void _press(String digit) {
    final pin = widget.controller.value;
    if (!widget.enabled || pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    final next = pin + digit;
    widget.controller.value = next;
    if (next.length == widget.length) widget.onCompleted(next);
  }

  void _delete() {
    final pin = widget.controller.value;
    if (!widget.enabled || pin.isEmpty) return;
    HapticFeedback.selectionClick();
    widget.controller.value = pin.substring(0, pin.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entered = widget.controller.value.length;
    final enabled = widget.enabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'PIN, $entered dari ${widget.length} digit diisi',
          liveRegion: true,
          child: ExcludeSemantics(
            child: Shake(
              trigger: _shakes,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpace.s4,
                children: [
                  for (var i = 0; i < widget.length; i++) _PinDot(filled: i < entered, error: widget.error),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s10),
        _KeyRow(
          children: [
            _DigitKey('1', enabled: enabled, onPress: _press),
            _DigitKey('2', enabled: enabled, onPress: _press),
            _DigitKey('3', enabled: enabled, onPress: _press),
          ],
        ),
        _KeyRow.gap,
        _KeyRow(
          children: [
            _DigitKey('4', enabled: enabled, onPress: _press),
            _DigitKey('5', enabled: enabled, onPress: _press),
            _DigitKey('6', enabled: enabled, onPress: _press),
          ],
        ),
        _KeyRow.gap,
        _KeyRow(
          children: [
            _DigitKey('7', enabled: enabled, onPress: _press),
            _DigitKey('8', enabled: enabled, onPress: _press),
            _DigitKey('9', enabled: enabled, onPress: _press),
          ],
        ),
        _KeyRow.gap,
        _KeyRow(
          children: [
            if (widget.onBiometric == null)
              const SizedBox.square(dimension: AppSizes.pinKey)
            else
              _PinKey(
                label: widget.biometricLabel,
                onTap: enabled ? widget.onBiometric : null,
                filled: false,
                child: AppIcon(
                  widget.biometricIcon,
                  size: AppSizes.iconXl,
                  color: c.textPrimary,
                ),
              ),
            _DigitKey('0', enabled: enabled, onPress: _press),
            _PinKey(
              label: 'Hapus',
              onTap: enabled && entered > 0 ? _delete : null,
              filled: false,
              child: AppIcon(
                AppIcons.backspace,
                size: AppSizes.iconLg,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One PIN dot: dashed when empty, ink when filled, bata on error.
class const _PinDot({required final bool filled, required final bool error}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const size = AppSizes.pinDot;
    if (!error && !filled) {
      return DashedBorder.circle(
        color: c.borderStrong,
        child: const SizedBox.square(dimension: size),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: error ? c.rejected.fg : c.textPrimary,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Three keys with the keypad gap between them.
class const _KeyRow({required final List<Widget> children}) extends StatelessWidget {
  static const gap = SizedBox(width: AppSpace.s6, height: AppSpace.s4);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AppSpace.s6,
    children: children,
  );
}

/// A 72 px round key. [onTap] null disables it.
class const _PinKey({
  required final String label,
  required final VoidCallback? onTap,
  required final Widget child,
  final bool filled = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    shape: const CircleBorder(),
    child: Container(
      width: AppSizes.pinKey,
      height: AppSizes.pinKey,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? context.colors.subtle : null,
        shape: BoxShape.circle,
      ),
      child: ExcludeSemantics(child: child),
    ),
  );
}

class const _DigitKey(final String digit, {required final bool enabled, required final ValueChanged<String> onPress})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _PinKey(
    label: digit,
    onTap: enabled ? () => onPress(digit) : null,
    child: Text(
      digit,
      style: AppTextStyles.of(context).titleLg.copyWith(
        color: context.colors.textPrimary,
        fontFeatures: AppTextStyles.tabularFigures,
      ),
    ),
  );
}
