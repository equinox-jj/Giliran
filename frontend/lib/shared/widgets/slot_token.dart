import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'avatar.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// A period's place in the cycle, as a Slot Token shows it.
enum SlotTokenState() {
  /// Drawn or closed: the winner's avatar in an ink ring.
  done,

  /// The open period: kunyit with an ink outline.
  current,

  /// Not started: a dashed ring with the period number.
  upcoming,
}

/// One period in the Period Strip (Tikar §9.2): 40 diameter in a 44 hit
/// area, with a kunyit `Scroll` badge when I won that period.
class const SlotToken({
  super.key,
  required final int periodNo,
  required final SlotTokenState state,
  final String? winnerName,
  final String? winnerAvatarUrl,
  final bool iWon = false,
  final bool selected = false,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  static const diameter = 40.0;
  static const hitSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = winnerName;
    final label = iWon
        ? l10n.slotTokenYouWon(periodNo)
        : switch (state) {
            SlotTokenState.done when name != null => l10n.slotTokenDoneWinner(periodNo, name),
            SlotTokenState.done => l10n.slotTokenDone(periodNo),
            SlotTokenState.current => l10n.slotTokenCurrent(periodNo),
            SlotTokenState.upcoming => l10n.slotTokenUpcoming(periodNo),
          };
    return Pressable(
      onTap: onTap,
      shape: const CircleBorder(),
      semanticLabel: label,
      selected: selected,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: hitSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: diameter,
                child: _Face(periodNo: periodNo, state: state, winnerName: name, winnerAvatarUrl: winnerAvatarUrl),
              ),
              if (selected && state != SlotTokenState.current) const _SelectionRing(),
              if (iWon) const PositionedDirectional(top: -2, end: -2, child: _WonBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class const _Face({
  required final int periodNo,
  required final SlotTokenState state,
  required final String? winnerName,
  required final String? winnerAvatarUrl,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return switch (state) {
      SlotTokenState.done => DecoratedBox(
        decoration: ShapeDecoration(
          shape: CircleBorder(
            side: BorderSide(color: c.textPrimary, width: AppStroke.ink),
          ),
        ),
        child: Center(
          child: winnerName == null
              ? AppIcon(AppIcons.check, size: AppSizes.iconMd, color: c.textPrimary)
              : AppAvatar(
                  name: winnerName!,
                  imageUrl: winnerAvatarUrl,
                  size: AppSizes.avatarSm,
                  semanticLabel: '',
                ),
        ),
      ),
      SlotTokenState.current => DecoratedBox(
        decoration: ShapeDecoration(
          color: c.turn,
          shape: CircleBorder(
            side: BorderSide(color: c.ink, width: AppStroke.ink),
          ),
        ),
        child: Center(
          child: AppIcon(AppIcons.shuffle, size: AppSizes.iconMd, color: c.ink),
        ),
      ),
      SlotTokenState.upcoming => DashedBorder.circle(
        color: c.borderStrong,
        child: Center(
          child: Text(
            '$periodNo',
            style: t.caption.copyWith(color: c.textTertiary, fontFeatures: AppTextStyles.tabularFigures),
          ),
        ),
      ),
    };
  }
}

class const _SelectionRing() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(color: context.colors.focus, width: AppStroke.strong),
        ),
      ),
      child: const SizedBox.square(dimension: SlotToken.hitSize),
    ),
  );
}

class const _WonBadge() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 18,
      height: 18,
      decoration: ShapeDecoration(
        color: c.turn,
        shape: CircleBorder(side: BorderSide(color: c.ink, width: 1)),
      ),
      alignment: Alignment.center,
      child: AppIcon(AppIcons.scrollFill, size: 11, color: c.ink),
    );
  }
}
