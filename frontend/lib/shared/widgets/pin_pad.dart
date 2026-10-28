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
class PinPadController extends ValueNotifier<String> {
  PinPadController() : super('');

  void clear() => value = '';
}

/// Six PIN dots plus a 3×4 keypad of 72 px keys. The biometric key
/// (bottom-left) shows only when [onBiometric] is set (lock screen).
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.length = 6,
    this.error = false,
    this.enabled = true,
    this.onBiometric,
    this.biometricIcon = AppIcons.fingerprint,
    this.biometricLabel = 'Buka dengan sidik jari',
  });

  final PinPadController controller;
  final ValueChanged<String> onCompleted;
  final int length;

  /// Wrong PIN: dots turn bata and shake. The parent clears the controller.
  final bool error;
  final bool enabled;
  final VoidCallback? onBiometric;

  /// `AppIcons.fingerprint` on Android, `AppIcons.scanSmiley` for Face ID.
  final String biometricIcon;
  final String biometricLabel;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
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
    final t = AppTextStyles.of(context);
    final entered = widget.controller.value.length;

    Widget dot(int i) {
      final filled = i < entered;
      final size = AppSizes.pinDot;
      if (widget.error) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.rejected.fg,
            shape: BoxShape.circle,
          ),
        );
      }
      return filled
          ? Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: c.textPrimary,
                shape: BoxShape.circle,
              ),
            )
          : DashedBorder.circle(
              color: c.borderStrong,
              child: SizedBox.square(dimension: size),
            );
    }

    Widget key({
      required Widget child,
      required VoidCallback? onTap,
      required String label,
      bool filled = true,
    }) => Pressable(
      onTap: widget.enabled ? onTap : null,
      semanticLabel: label,
      shape: const CircleBorder(),
      child: Container(
        width: AppSizes.pinKey,
        height: AppSizes.pinKey,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? c.subtle : null,
          shape: BoxShape.circle,
        ),
        child: ExcludeSemantics(child: child),
      ),
    );

    Widget digit(String d) => key(
      label: d,
      onTap: () => _press(d),
      child: Text(
        d,
        style: t.titleLg.copyWith(
          color: c.textPrimary,
          fontFeatures: AppTextStyles.tabularFigures,
        ),
      ),
    );

    const gap = SizedBox(width: AppSpace.s6, height: AppSpace.s4);
    Widget row(List<Widget> keys) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [keys[0], gap, keys[1], gap, keys[2]],
    );

    final empty = const SizedBox.square(dimension: AppSizes.pinKey);

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
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpace.s4),
                    dot(i),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s10),
        row([digit('1'), digit('2'), digit('3')]),
        gap,
        row([digit('4'), digit('5'), digit('6')]),
        gap,
        row([digit('7'), digit('8'), digit('9')]),
        gap,
        row([
          widget.onBiometric == null
              ? empty
              : key(
                  label: widget.biometricLabel,
                  onTap: widget.onBiometric,
                  filled: false,
                  child: AppIcon(
                    widget.biometricIcon,
                    size: AppSizes.iconXl,
                    color: c.textPrimary,
                  ),
                ),
          digit('0'),
          key(
            label: 'Hapus',
            onTap: entered == 0 ? null : _delete,
            filled: false,
            child: AppIcon(
              AppIcons.backspace,
              size: AppSizes.iconLg,
              color: c.textPrimary,
            ),
          ),
        ]),
      ],
    );
  }
}
