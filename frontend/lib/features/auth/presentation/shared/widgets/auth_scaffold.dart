import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

/// The frame of every sign-in and PIN screen (S03–S09): the compact top bar,
/// a body capped at [maxWidth], and an optional [bottom] action docked above
/// the keyboard.
///
/// The body fills at least the space under the bar, so it can push content
/// down with a `Spacer` (the PIN keypad sits at the bottom on S04, S06 and
/// S08), and it scrolls when it is taller than the screen.
///
/// Screens that show a `PinPad` set [pinPad]: the body fills the space under
/// the bar without scrolling, so the pad can size its keys to fit, and it
/// widens to [PinPad.splitMaxWidth] when the pad splits in two.
class const AuthScaffold({
  super.key,
  required final Widget body,
  final String? title,

  /// A small caption-sized label in place of [title], such as
  /// "Langkah 1 dari 2".
  final String? step,
  final bool showBack = true,

  /// Off for full-screen layouts with nothing in the bar (S08 lock).
  final bool showTopBar = true,
  final VoidCallback? onBack,
  final Widget? bottom,
  final double maxWidth = formMax,
  final bool centerBody = false,
  final bool pinPad = false,
}) extends StatelessWidget {
  /// Max width of the sign-in forms and the email code card.
  static const formMax = 420.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;
    final t = AppTextStyles.of(context);

    return Scaffold(
      backgroundColor: context.colors.page,
      appBar: showTopBar
          ? AppTopBar(
              title: step ?? title,
              titleStyle: step == null ? null : t.caption.copyWith(fontWeight: FontWeight.w600),
              showBack: showBack,
              onBack: onBack,
            )
          : null,
      body: SafeArea(
        top: !showTopBar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: pinPad
                  ? _FixedBody(maxWidth: maxWidth, body: body)
                  : _ScrollBody(maxWidth: maxWidth, centerBody: centerBody, body: body),
            ),
            if (bottom case final bottom?)
              Padding(
                padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s4),
                child: MaxWidth(width: maxWidth, child: bottom),
              ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling body: at least as tall as the space under the bar.
class const _ScrollBody({
  required final double maxWidth,
  required final bool centerBody,
  required final Widget body,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;

    return CustomScrollView(
      slivers: [
        // `SliverFillRemaining` sizes the body by its intrinsic height at the
        // sliver's width, so the side padding (not a `ConstrainedBox`) caps
        // the width; otherwise text measured wider than it lays out wraps
        // into an overflow.
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(margin, (constraints.crossAxisExtent - maxWidth) / 2);
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(side, AppSpace.s2, side, AppSpace.s6),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: centerBody ? Alignment.center : Alignment.topCenter,
                  child: SizedBox(width: double.infinity, child: body),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The [AuthScaffold.pinPad] body: exactly the space under the bar.
class const _FixedBody({required final double maxWidth, required final Widget body}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;
    final width = PinPad.splitFor(MediaQuery.sizeOf(context)) ? PinPad.splitMaxWidth : maxWidth;

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: SizedBox.expand(child: body),
        ),
      ),
    );
  }
}
