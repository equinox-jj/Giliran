import '../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'adaptive/app_sheet.dart';
import 'app_icon.dart';
import 'circle_icon_button.dart';
import 'pressable.dart';

/// One action in an [OverflowMenuButton].
class const OverflowMenuItem({
  required final String label,
  required final String icon,
  required final VoidCallback onSelected,

  /// Shown last, below a hairline, in `rejected.fg`.
  final bool destructive = false,
}) {}

/// `DotsThree` circle button that opens an action sheet on phones and an
/// anchored 280-wide popup from medium up. At most 7 items.
class const OverflowMenuButton({
  super.key,
  required final List<OverflowMenuItem> items,
  final String? semanticLabel,
}) extends StatelessWidget {
  this : assert(items.length <= 7, 'Never more than 7 items');

  List<OverflowMenuItem> get _regular => items.where((i) => !i.destructive).toList();

  List<OverflowMenuItem> get _destructive => items.where((i) => i.destructive).toList();

  Future<void> _open(BuildContext context) async {
    if (context.isCompact) {
      final selected = await showAppSheet<OverflowMenuItem>(
        context,
        builder: (context) => AppSheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in _regular) _SheetRow(item),
              if (_destructive.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s2),
                Divider(color: context.colors.hairline),
                const SizedBox(height: AppSpace.s2),
                for (final item in _destructive) _SheetRow(item),
              ],
            ],
          ),
        ),
      );
      selected?.onSelected();
      return;
    }

    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    PopupMenuItem<OverflowMenuItem> entry(OverflowMenuItem item) => PopupMenuItem(
      value: item,
      height: AppSizes.tapMin,
      child: _MenuRow(item),
    );

    final selected = await showMenu<OverflowMenuItem>(
      context: context,
      position: position,
      constraints: const BoxConstraints.tightFor(width: 280),
      items: [
        for (final item in _regular) entry(item),
        if (_destructive.isNotEmpty) const PopupMenuDivider(),
        for (final item in _destructive) entry(item),
      ],
    );
    selected?.onSelected();
  }

  @override
  Widget build(BuildContext context) => CircleIconButton(
    icon: AppIcons.dotsThree,
    semanticLabel: semanticLabel ?? context.l10n.widgetMenu,
    onPressed: () => _open(context),
  );
}

class const _SheetRow(final OverflowMenuItem item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = item.destructive ? c.rejected.fg : c.textPrimary;
    return Pressable(
      onTap: () => Navigator.of(context).pop(item),
      semanticLabel: item.label,
      shape: AppShapes.squircle(AppRadius.sm),
      scale: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            AppIcon(item.icon, size: AppSizes.iconLg, color: color),
            const SizedBox(width: AppSpace.s4),
            Expanded(
              child: Text(item.label, style: t.bodyLg.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Popup-menu row on medium and up.
class const _MenuRow(final OverflowMenuItem item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = item.destructive ? c.rejected.fg : c.textPrimary;
    return Row(
      children: [
        AppIcon(
          item.icon,
          size: AppSizes.iconMd,
          color: item.destructive ? c.rejected.fg : c.textSecondary,
        ),
        const SizedBox(width: AppSpace.s3),
        Text(item.label, style: t.body.copyWith(color: color)),
      ],
    );
  }
}
