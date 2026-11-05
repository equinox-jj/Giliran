import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/code_formatter.dart';
import 'app_icon.dart';
import 'avatar.dart';

/// Reorderable member row (Tikar §8.18) for Fixed order: the position
/// in a kunyit token, avatar and name, the slot number, and a drag handle.
/// Screen readers get "Naikkan" / "Turunkan" actions instead of dragging.
/// Inside a `ReorderableListView`, pass [dragIndex] so the handle starts a
/// drag; [locked] shows the row read-only.
class const ReorderableMemberRow({
  super.key,
  required final int position,
  required final String name,
  required final int slotNo,
  final String? avatarUrl,
  final bool guest = false,
  final VoidCallback? onMoveUp,
  final VoidCallback? onMoveDown,
  final int? dragIndex,
  final bool locked = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final slot = CodeFormatter.slotNo(slotNo);
    final index = dragIndex;
    final handle = SizedBox.square(
      dimension: 48,
      child: Center(child: AppIcon(AppIcons.dotsSixVertical, color: c.textSecondary)),
    );
    return Semantics(
      container: true,
      label: l10n.reorderPositionSemantics(position, name, slot),
      customSemanticsActions: locked
          ? null
          : {
              CustomSemanticsAction(label: l10n.reorderMoveUp): ?onMoveUp,
              CustomSemanticsAction(label: l10n.reorderMoveDown): ?onMoveDown,
            },
      child: ExcludeSemantics(
        child: Container(
          height: 72,
          padding: const EdgeInsetsDirectional.only(start: AppSpace.s3, end: AppSpace.s1),
          decoration: ShapeDecoration(color: c.surface, shape: AppShapes.squircle(AppRadius.lg)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: c.turn,
                  shape: CircleBorder(
                    side: BorderSide(color: c.ink, width: AppStroke.regular),
                  ),
                ),
                child: Text('$position', style: t.label.copyWith(color: c.ink)),
              ),
              const SizedBox(width: AppSpace.s3),
              AppAvatar(name: name, imageUrl: avatarUrl, guest: guest),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: t.title.copyWith(color: c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(l10n.memberSlotCaption(slot), style: t.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              if (!locked) index == null ? handle : ReorderableDragStartListener(index: index, child: handle),
            ],
          ),
        ),
      ),
    );
  }
}
