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

class const PinPad({
  super.key,
  required final PinPadController controller,
  required final ValueChanged<String> onCompleted,
  final int length = 6,

  /// Above the dots: the screen's headline or greeting, with its spacing.
  final Widget? header,

  /// Shown under the dots: the error line, a hint banner.
  final Widget? belowDots,

  /// Under the keypad, or under the dots when split: "Lupa PIN?" and the
  /// like, with its spacing.
  final Widget? footer,

  /// Pushes the keypad to the bottom of the available height.
  final bool expand = false,

  /// Wrong PIN: dots turn bata and shake. The parent clears the controller.
  final bool error = false,
  final bool enabled = true,

  /// Verifying the entry: the dots dim, a spinner shows under them and the
  /// keys are off, like `OtpInput.checking`. The entered dots stay filled.
  final bool checking = false,
  final VoidCallback? onBiometric,

  /// `AppIcons.fingerprint` on Android, `AppIcons.scanSmiley` for Face ID.
  final String biometricIcon = AppIcons.fingerprint,
  final String biometricLabel = 'Buka dengan sidik jari',
}) extends StatefulWidget {
  /// Width cap of a split pad, so the two panes stay close on wide phones.
  static const splitMaxWidth = 720.0;

  /// Whether an expanded pad splits into two panes on a window of [size]:
  /// landscape and too short to stack the header over the keypad (a phone
  /// on its side, a small tablet in landscape).
  static bool splitFor(Size size) => size.width > size.height && size.height < Breakpoints.medium;

  /// The key size for a screen of [size] with side [margin]: scales with the
  /// height (72 px at 844 tall) so the pad fits short phones and fills
  /// tablets, never wider than three keys and their gaps can take, and
  /// clamped to [AppSizes.pinKeyMin]..[AppSizes.pinKeyMax].
  static double keySizeFor(Size size, {required double margin}) {
    const byHeightRatio = AppSizes.pinKey / 844;
    final byWidth = (size.width - 2 * margin) / (3 + 2 * _KeyRow.hGapRatio);
    final key = size.height * byHeightRatio;
    return (key < byWidth ? key : byWidth).clamp(AppSizes.pinKeyMin, AppSizes.pinKeyMax);
  }

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

  bool get _enabled => widget.enabled && !widget.checking;

  void _press(String digit) {
    final pin = widget.controller.value;
    if (!_enabled || pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    final next = pin + digit;
    widget.controller.value = next;
    if (next.length == widget.length) widget.onCompleted(next);
  }

  void _delete() {
    final pin = widget.controller.value;
    if (!_enabled || pin.isEmpty) return;
    HapticFeedback.selectionClick();
    widget.controller.value = pin.substring(0, pin.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final entered = widget.controller.value.length;
    final size = MediaQuery.sizeOf(context);
    final split = widget.expand && PinPad.splitFor(size);
    // The bata dots mark the rejected entry only; typing again shows progress.
    final dots = _Dots(
      length: widget.length,
      entered: entered,
      error: widget.error && entered == 0,
      shakes: _shakes,
      checking: widget.checking,
    );
    final keypad = _Keypad(
      // Split, the pane's height sets the size; stacked, the screen does.
      preferred: split ? AppSizes.pinKey : PinPad.keySizeFor(size, margin: context.screenMargin),
      alignment: split ? Alignment.center : Alignment.bottomCenter,
      enabled: _enabled,
      canDelete: _enabled && entered > 0,
      onPress: _press,
      onDelete: _delete,
      onBiometric: widget.onBiometric,
      biometricIcon: widget.biometricIcon,
      biometricLabel: widget.biometricLabel,
    );

    if (split) {
      return Row(
        spacing: AppSpace.s8,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [?widget.header, dots, ?widget.belowDots, ?widget.footer],
                ),
              ),
            ),
          ),
          Expanded(child: keypad),
        ],
      );
    }

    if (widget.expand) {
      return _ExpandedLayout(
        top: Column(
          mainAxisSize: MainAxisSize.min,
          children: [?widget.header, dots, ?widget.belowDots],
        ),
        // The fixed gap keeps the hint strip off the keypad.
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpace.s6),
            keypad,
            ?widget.footer,
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?widget.header,
        dots,
        ?widget.belowDots,
        const SizedBox(height: AppSpace.s10),
        keypad,
        ?widget.footer,
      ],
    );
  }
}

/// The stacked expanded pad: [top] (header, dots) at the top and [bottom]
/// (keypad, footer) at the bottom of the available height. The keys keep
/// the screen's size on every PIN screen, so when a short window can't hold
/// both, the pad scrolls instead of shrinking them.
class const _ExpandedLayout({
  required final Widget top,
  required final Widget bottom,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [top, bottom],
        ),
      ),
    ),
  );
}

/// The row of PIN dots, which shakes when [shakes] goes up, dimmed with a
/// spinner under it while [checking].
class const _Dots({
  required final int length,
  required final int entered,
  required final bool error,
  required final int shakes,
  required final bool checking,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: checking ? 'Memeriksa PIN' : 'PIN, $entered dari $length digit diisi',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: checking ? 0.5 : 1,
            duration: AppMotion.quick,
            child: Shake(
              trigger: shakes,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpace.s4,
                children: [
                  for (var i = 0; i < length; i++) _PinDot(filled: i < entered, error: error),
                ],
              ),
            ),
          ),
          if (checking) ...[
            const SizedBox(height: AppSpace.s3),
            // The spinner repaints every frame. Its own layer keeps that from
            // repainting the dots, the keypad and the rest of the screen.
            RepaintBoundary(
              child: SizedBox.square(
                dimension: AppSizes.iconSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// The 3×4 keys at [preferred] size, smaller when the space it gets can't
/// hold them, placed at [alignment] in that space.
class const _Keypad({
  required final double preferred,
  required final AlignmentGeometry alignment,
  required final bool enabled,
  required final bool canDelete,
  required final ValueChanged<String> onPress,
  required final VoidCallback onDelete,
  required final VoidCallback? onBiometric,
  required final String biometricIcon,
  required final String biometricLabel,
}) extends StatelessWidget {
  /// The largest key, up to [preferred], whose keypad fits [constraints].
  double _fit(BoxConstraints constraints) {
    final byHeight = constraints.maxHeight / (4 + 3 * _KeyRow.vGapRatio);
    final byWidth = constraints.maxWidth / (3 + 2 * _KeyRow.hGapRatio);
    return [preferred, byHeight, byWidth].reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final key = _fit(constraints);
        final gap = SizedBox(height: key * _KeyRow.vGapRatio);
        return Align(
          alignment: alignment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeyRow(
                size: key,
                children: [
                  _DigitKey('1', size: key, enabled: enabled, onPress: onPress),
                  _DigitKey('2', size: key, enabled: enabled, onPress: onPress),
                  _DigitKey('3', size: key, enabled: enabled, onPress: onPress),
                ],
              ),
              gap,
              _KeyRow(
                size: key,
                children: [
                  _DigitKey('4', size: key, enabled: enabled, onPress: onPress),
                  _DigitKey('5', size: key, enabled: enabled, onPress: onPress),
                  _DigitKey('6', size: key, enabled: enabled, onPress: onPress),
                ],
              ),
              gap,
              _KeyRow(
                size: key,
                children: [
                  _DigitKey('7', size: key, enabled: enabled, onPress: onPress),
                  _DigitKey('8', size: key, enabled: enabled, onPress: onPress),
                  _DigitKey('9', size: key, enabled: enabled, onPress: onPress),
                ],
              ),
              gap,
              _KeyRow(
                size: key,
                children: [
                  if (onBiometric == null)
                    SizedBox.square(dimension: key)
                  else
                    _PinKey(
                      size: key,
                      label: biometricLabel,
                      onTap: enabled ? onBiometric : null,
                      filled: false,
                      outlined: true,
                      child: AppIcon(biometricIcon, size: 28, color: c.textPrimary),
                    ),
                  _DigitKey('0', size: key, enabled: enabled, onPress: onPress),
                  _PinKey(
                    size: key,
                    label: 'Hapus',
                    onTap: canDelete ? onDelete : null,
                    filled: false,
                    child: AppIcon(AppIcons.backspace, size: 26, color: c.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

/// Three keys of [size] with the keypad gap between them.
class const _KeyRow({required final double size, required final List<Widget> children}) extends StatelessWidget {
  /// The gaps keep the design's proportions at any key size: 34 px across
  /// and 16 px down at the 72 px key (three 106 px columns on a 390 phone).
  static const hGapRatio = 34 / AppSizes.pinKey;
  static const vGapRatio = AppSpace.s4 / AppSizes.pinKey;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: size * hGapRatio,
    children: children,
  );
}

/// A round key of [size]. [onTap] null disables it. [outlined] draws the
/// hairline ring of the biometric key.
class const _PinKey({
  required final double size,
  required final String label,
  required final VoidCallback? onTap,
  required final Widget child,
  final bool filled = true,
  final bool outlined = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    shape: const CircleBorder(),
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? context.colors.subtle : null,
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: context.colors.hairline, width: AppStroke.regular) : null,
      ),
      child: ExcludeSemantics(child: child),
    ),
  );
}

class const _DigitKey(
  final String digit, {
  required final double size,
  required final bool enabled,
  required final ValueChanged<String> onPress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _PinKey(
    size: size,
    label: digit,
    onTap: enabled ? () => onPress(digit) : null,
    child: Text(
      digit,
      // 24 px bold digits, a size up from `titleLg`.
      style: AppTextStyles.of(context).titleLg.copyWith(
        fontSize: 24,
        height: 1,
        letterSpacing: 0,
        color: context.colors.textPrimary,
        fontFeatures: AppTextStyles.tabularFigures,
      ),
    ),
  );
}
