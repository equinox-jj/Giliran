import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'pressable.dart';

enum _SettingsRowKind() {
  navigation,
  toggle,
  info,
  locked,
  destructive,
}

/// Settings row: 56 high (64 with a subtitle), padding 16, a 24 px leading
/// icon in `text.secondary`. Group rows with [SettingsGroup].
class SettingsRow extends StatelessWidget {
  /// Opens a screen; shows [value] and a `CaretRight`.
  const new navigation({
    super.key,
    required this.label,
    required VoidCallback this.onTap,
    this.icon,
    this.subtitle,
    this.value,
  }) : _kind = _SettingsRowKind.navigation,
       toggleValue = null,
       onToggle = null;

  /// Adaptive switch; track is `paid.fg` when on.
  const new toggle({
    super.key,
    required this.label,
    required this.toggleValue,
    required this.onToggle,
    this.icon,
    this.subtitle,
  }) : _kind = _SettingsRowKind.toggle,
       value = null,
       onTap = null;

  /// Read-only value (email, app version).
  const new info({
    super.key,
    required this.label,
    required String this.value,
    this.icon,
    this.subtitle,
  }) : _kind = _SettingsRowKind.info,
       toggleValue = null,
       onToggle = null,
       onTap = null;

  /// Disabled after the group starts: grey label and value with a lock. The
  /// reason goes once under the group ([SettingsGroup.footer]).
  const new locked({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.subtitle,
  }) : _kind = _SettingsRowKind.locked,
       toggleValue = null,
       onToggle = null,
       onTap = null;

  /// Label in `rejected.fg`, no trailing.
  const new destructive({
    super.key,
    required this.label,
    required VoidCallback this.onTap,
    this.icon,
    this.subtitle,
  }) : _kind = _SettingsRowKind.destructive,
       value = null,
       toggleValue = null,
       onToggle = null;

  /// Largest share of the row a trailing value may take.
  static const _valueMaxFraction = 0.45;

  final _SettingsRowKind _kind;
  final String label;
  final String? icon;
  final String? subtitle;
  final String? value;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final destructive = _kind == _SettingsRowKind.destructive;
    final locked = _kind == _SettingsRowKind.locked;
    final labelColor = destructive
        ? c.rejected.fg
        : locked
        ? c.textTertiary
        : c.textPrimary;

    final row = Container(
      constraints: BoxConstraints(
        minHeight: subtitle == null ? AppSizes.settingsRowH : AppSizes.settingsRowHWithSubtitle,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A value never takes more than [_valueMaxFraction] of the row, so
          // the label keeps the rest and wraps only when it must.
          final valueMax = constraints.maxWidth * _valueMaxFraction;
          final Widget? trailingWidget = switch (_kind) {
            _SettingsRowKind.navigation => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) ...[
                  _TrailingValue(text: value!, color: c.textSecondary, maxWidth: valueMax),
                  const SizedBox(width: AppSpace.s1),
                ],
                AppIcon(
                  AppIcons.caretRight,
                  size: AppSizes.iconMd,
                  color: c.textTertiary,
                ),
              ],
            ),
            _SettingsRowKind.toggle => Switch.adaptive(
              value: toggleValue!,
              onChanged: onToggle,
              activeTrackColor: c.paid.fg,
            ),
            _SettingsRowKind.info => _TrailingValue(text: value!, color: c.textSecondary, maxWidth: valueMax),
            _SettingsRowKind.locked => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) ...[
                  _TrailingValue(text: value!, color: c.textTertiary, maxWidth: valueMax),
                  const SizedBox(width: AppSpace.s1),
                ],
                AppIcon(
                  AppIcons.lockSimple,
                  size: AppSizes.iconSm,
                  color: c.textTertiary,
                ),
              ],
            ),
            _SettingsRowKind.destructive => null,
          };
          return Row(
            children: [
              if (icon != null) ...[
                AppIcon(
                  icon!,
                  size: AppSizes.iconLg,
                  color: destructive ? c.rejected.fg : c.textSecondary,
                ),
                const SizedBox(width: AppSpace.s3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: t.bodyLg.copyWith(color: labelColor)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: t.caption.copyWith(color: destructive ? c.rejected.fg : c.textTertiary),
                      ),
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: AppSpace.s3),
                trailingWidget,
              ],
            ],
          );
        },
      ),
    );

    return switch (_kind) {
      _SettingsRowKind.navigation || _SettingsRowKind.destructive => Pressable(
        onTap: onTap,
        semanticLabel: [label, ?value].join(', '),
        shape: const RoundedRectangleBorder(),
        scale: false,
        child: ExcludeSemantics(child: row),
      ),
      _SettingsRowKind.toggle => MergeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle == null ? null : () => onToggle!(!toggleValue!),
          child: row,
        ),
      ),
      _ => MergeSemantics(child: row),
    };
  }
}

/// Rows grouped into a `radius.md` card with hairlines inside, an optional
/// `caption`/600 header in `text.tertiary`, an optional [footer] caption
/// under the card, and 24 px below the group.
class const SettingsGroup({
  super.key,
  final String? header,
  required final List<Widget> children,

  /// A note for the whole group, such as why its rows are locked.
  final String? footer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpace.s1,
                bottom: AppSpace.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  header!,
                  style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Container(
            decoration: ShapeDecoration(
              color: c.surface,
              shape: AppShapes.squircle(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpace.s4),
                      child: Divider(color: c.hairline),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer case final footer?)
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.s1, top: AppSpace.s2, right: AppSpace.s1),
              child: Text(footer, style: t.caption.copyWith(color: c.textTertiary)),
            ),
        ],
      ),
    );
  }
}

/// A one-line trailing value, capped at [maxWidth] and ellipsized.
class const _TrailingValue({
  required final String text,
  required final Color color,
  required final double maxWidth,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(
      text,
      style: AppTextStyles.of(context).body.copyWith(color: color),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );
}
