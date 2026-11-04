import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'activity_row.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// One push in the Aktivitas tab (Tikar 8.24): the activity row look plus
/// an 8 px group tone dot and the group name above the title. Unread items
/// sit on `bg.surface` with a 4 px kunyit bar and a bold title. Swiping
/// marks it read without removing it; tapping opens its target.
class const NotificationItem({
  super.key,

  /// Stable per notification; keys the swipe.
  required final String id,
  required final String icon,
  required final String title,
  final String? body,
  required final String time,
  final String? groupName,
  final Color? toneColor,
  required final bool read,
  required final VoidCallback onTap,
  required final VoidCallback onMarkRead,
}) extends StatelessWidget {
  static const _barWidth = 4.0;
  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final label = [
      read ? title : l10n.notificationUnreadSemantics(title),
      ?groupName,
      ?body,
      time,
    ].join(', ');
    return Dismissible(
      key: ValueKey('notification-$id'),
      direction: read ? DismissDirection.none : DismissDirection.horizontal,
      // Reading doesn't remove the item: the swipe springs back.
      confirmDismiss: (_) async {
        onMarkRead();
        return false;
      },
      background: _SwipeBackground(alignment: AlignmentDirectional.centerStart, label: l10n.notificationMarkReadAction),
      secondaryBackground: _SwipeBackground(
        alignment: AlignmentDirectional.centerEnd,
        label: l10n.notificationMarkReadAction,
      ),
      child: Semantics(
        customSemanticsActions: read
            ? null
            : {CustomSemanticsAction(label: l10n.notificationMarkReadAction): onMarkRead},
        child: Pressable(
          onTap: onTap,
          semanticLabel: label,
          shape: const RoundedRectangleBorder(),
          scale: false,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(color: read ? null : c.surface),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _barWidth,
                      child: read ? null : ColoredBox(color: c.turn),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
                      child: _Leading(icon: icon),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpace.s3,
                          bottom: AppSpace.s3,
                          end: AppSpace.s4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (groupName != null) _GroupLine(name: groupName!, tone: toneColor),
                            Text(
                              title,
                              style: (read ? t.body : t.label).copyWith(color: c.textPrimary),
                            ),
                            if (body != null && body!.isNotEmpty)
                              Text(body!, style: t.body.copyWith(color: c.textSecondary)),
                            const SizedBox(height: 2),
                            Text(time, style: t.caption.copyWith(color: c.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _Leading({required final String icon}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: ActivityRow.leadingSize,
      height: ActivityRow.leadingSize,
      decoration: ShapeDecoration(color: c.subtle, shape: const CircleBorder()),
      alignment: Alignment.center,
      child: AppIcon(icon, size: AppSizes.iconSm, color: c.textSecondary),
    );
  }
}

class const _GroupLine({required final String name, required final Color? tone}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: NotificationItem._dot,
            height: NotificationItem._dot,
            decoration: ShapeDecoration(color: tone ?? c.textTertiary, shape: const CircleBorder()),
          ),
          const SizedBox(width: AppSpace.s1),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.of(context).micro.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class const _SwipeBackground({required final AlignmentGeometry alignment, required final String label})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.subtle,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Text(label, style: AppTextStyles.of(context).label.copyWith(color: c.textSecondary)),
        ),
      ),
    );
  }
}
