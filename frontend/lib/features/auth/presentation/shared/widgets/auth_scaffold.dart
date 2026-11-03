import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';

/// Where a multi-step flow is, for the [AuthScaffold.progress] bar:
/// "Lupa PIN · 1 dari 3" over three segments.
typedef AuthProgress = ({String label, int step, int total});

class const AuthScaffold({
  super.key,
  required final Widget body,
  final String? title,

  /// A small caption-sized label in place of [title], such as
  /// "Langkah 1 dari 2".
  final String? step,

  /// The [step] label color; `text.tertiary` when null.
  final Color? stepColor,

  final AuthProgress? progress,
  final bool showBack = true,

  final bool modal = false,

  final bool showTopBar = true,
  final VoidCallback? onBack,
  final Widget? bottom,
  final double maxWidth = formMax,
  final bool centerBody = false,
  final bool pinPad = false,

  /// Space between the bar and the body.
  final double topPadding = AppSpace.s2,

  /// Space under the [bottom] action.
  final double bottomPadding = AppSpace.s6,
}) extends StatelessWidget {
  /// Max width of the sign-in forms and the email code card.
  static const formMax = 420.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final progress = this.progress;

    final PreferredSizeWidget? bar = !showTopBar
        ? null
        : progress != null
        ? _ProgressTopBar(progress: progress, onClose: onBack)
        : AppTopBar(
            title: step ?? title,
            titleStyle: step == null
                ? null
                : t.caption.copyWith(fontWeight: FontWeight.w600, color: stepColor ?? c.textTertiary),
            showBack: showBack,
            modal: modal,
            onBack: onBack,
          );

    return Scaffold(
      backgroundColor: c.page,
      appBar: bar,
      body: SafeArea(
        top: !showTopBar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: pinPad
                  ? _FixedBody(maxWidth: maxWidth, top: topPadding, body: body)
                  : _ScrollBody(maxWidth: maxWidth, top: topPadding, centerBody: centerBody, body: body),
            ),
            if (bottom case final bottom?)
              Padding(
                padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, bottomPadding),
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
  required final double top,
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
              padding: EdgeInsets.fromLTRB(side, top, side, AppSpace.s6),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: centerBody ? Alignment.center : Alignment.topCenter,
                  child: SizedBox(
                    width: constraints.crossAxisExtent - 2 * side,
                    child: body,
                  ),
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
class const _FixedBody({
  required final double maxWidth,
  required final double top,
  required final Widget body,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;
    final width = PinPad.splitFor(MediaQuery.sizeOf(context)) ? PinPad.splitMaxWidth : maxWidth;

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, top, margin, AppSpace.s6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: SizedBox.expand(child: body),
        ),
      ),
    );
  }
}

class const _ProgressTopBar({required final AuthProgress progress, required final VoidCallback? onClose})
    extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.topBarH);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final (:label, :step, :total) = progress;

    return Material(
      color: c.page,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSizes.topBarH,
          child: Padding(
            // The close button's hit area reaches 2 px past its circle.
            padding: EdgeInsets.symmetric(horizontal: context.screenMargin - 2),
            child: Row(
              children: [
                CircleIconButton(
                  icon: AppIcons.x,
                  semanticLabel: 'Tutup',
                  onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    label: '$label, langkah $step dari $total',
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            '$label · $step dari $total',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                          Row(
                            spacing: AppSpace.s1,
                            children: [
                              for (var i = 0; i < total; i++)
                                Expanded(
                                  child: Container(
                                    height: AppSpace.s1,
                                    decoration: ShapeDecoration(
                                      color: i < step ? c.ink : c.hairline,
                                      shape: AppShapes.pill,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
