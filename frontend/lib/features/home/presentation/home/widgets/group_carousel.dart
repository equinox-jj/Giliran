import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/domain/entities/group_summary.dart';

/// The Home carousel of Group Cards (260 × 220, 12 px gap, the next card
/// peeking), ending with the dashed "Buat grup / Gabung lewat link" card.
class const GroupCarousel({
  super.key,
  required final List<GroupSummary> groups,
  required final ValueChanged<String> onOpenGroup,
  required final VoidCallback onCreateGroup,
  required final VoidCallback onJoinByLink,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final margin = context.screenMargin;
    return SizedBox(
      height: GroupCard.carouselHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        itemCount: groups.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s3),
        itemBuilder: (context, i) {
          if (i == groups.length) {
            return CreateOrJoinCard(onCreateGroup: onCreateGroup, onJoinByLink: onJoinByLink);
          }
          final group = groups[i];
          return GroupCard(group: group, onTap: () => onOpenGroup(group.id ?? ''));
        },
      ),
    );
  }
}

/// The dashed last card of the carousel and grid: create a group or join
/// one with an invite link.
class const CreateOrJoinCard({
  super.key,
  required final VoidCallback onCreateGroup,
  required final VoidCallback onJoinByLink,
  final bool fill = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = AppCard(
      style: AppCardStyle.dashed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppButton(
            label: l10n.createGroupButton,
            icon: AppIcons.plus,
            size: AppButtonSize.small,
            onPressed: onCreateGroup,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.secondary(
            label: l10n.joinByLinkButton,
            icon: AppIcons.linkSimple,
            size: AppButtonSize.small,
            onPressed: onJoinByLink,
          ),
        ],
      ),
    );
    if (fill) return card;
    return SizedBox(width: GroupCard.carouselWidth, height: GroupCard.carouselHeight, child: card);
  }
}
