import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_badge.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// A navigation destination. [icon] is the Regular asset, [activeIcon] the
/// Fill asset.
class const AppNavDestination({
  required final String label,
  required final String icon,
  required final String activeIcon,
  final bool showDot = false,
}) {
  /// Beranda · Grup · Aktivitas · Profil.
  static const main = [
    AppNavDestination(
      label: 'Beranda',
      icon: AppIcons.houseSimple,
      activeIcon: AppIcons.houseSimpleFill,
    ),
    AppNavDestination(
      label: 'Grup',
      icon: AppIcons.usersThree,
      activeIcon: AppIcons.usersThreeFill,
    ),
    AppNavDestination(
      label: 'Aktivitas',
      icon: AppIcons.bellSimple,
      activeIcon: AppIcons.bellSimpleFill,
    ),
    AppNavDestination(
      label: 'Profil',
      icon: AppIcons.userCircle,
      activeIcon: AppIcons.userCircleFill,
    ),
  ];
}

class const _NavItem({
  required final AppNavDestination destination,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = selected ? c.textPrimary : c.textTertiary;

    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: destination.label,
      shape: AppShapes.squircle(AppRadius.sm),
      tint: false,
      child: SizedBox(
        width: 72,
        height: AppSizes.navH - AppSpace.s2,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppIcon(
                    selected ? destination.activeIcon : destination.icon,
                    size: AppSizes.iconLg,
                    color: color,
                  ),
                  if (destination.showDot) const Positioned(top: -3, right: -5, child: CountDot()),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: t.micro.copyWith(color: color, letterSpacing: 0.2),
                maxLines: 1,
              ),
              const SizedBox(height: 3),
              // Active dot: kunyit with an ink outline.
              Container(
                width: 6,
                height: 6,
                decoration: selected
                    ? BoxDecoration(
                        color: c.turn,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.ink, width: 1),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating pill bottom bar for compact windows: 64 high, 16 from the bottom
/// safe area, `bg.surfaceRaised`, float elevation and a hairline.
class const AppBottomNavBar({
  super.key,
  required final List<AppNavDestination> destinations,
  required final int selectedIndex,
  required final ValueChanged<int> onSelected,
}) extends StatelessWidget {
  /// Bottom padding lists inside [AppNavShell] need so nothing hides behind
  /// the bar. The shell's `extendBody` already adds the bar's full height
  /// (bar + gap + safe area) to the body's bottom padding, so only the 16
  /// breathing gap goes on top.
  static double contentInset(BuildContext context) => MediaQuery.paddingOf(context).bottom + AppSizes.navBottomGap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSizes.navBottomGap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: Container(
            height: AppSizes.navH,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            decoration: ShapeDecoration(
              color: c.surfaceRaised,
              shape: StadiumBorder(side: BorderSide(color: c.hairline)),
              shadows: AppElevation.float(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _NavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 88-wide navigation rail for medium and expanded windows. [leading] holds
/// the app mark and the "Buat grup" action.
class const AppNavRail({
  super.key,
  required final List<AppNavDestination> destinations,
  required final int selectedIndex,
  required final ValueChanged<int> onSelected,
  final Widget? leading,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: AppSizes.railW,
      decoration: BoxDecoration(
        color: c.page,
        border: Border(right: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpace.s4),
            if (leading != null) ...[
              leading!,
              const SizedBox(height: AppSpace.s6),
            ],
            for (var i = 0; i < destinations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// App shell that shows the floating bar on compact windows and the rail
/// from medium up. Pair with a go_router `StatefulShellRoute`.
class const AppNavShell({
  super.key,
  required final Widget body,
  required final int selectedIndex,
  required final ValueChanged<int> onSelected,
  final List<AppNavDestination> destinations = AppNavDestination.main,
  final Widget? railLeading,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Scaffold(
        extendBody: true,
        body: body,
        bottomNavigationBar: AppBottomNavBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          AppNavRail(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
            leading: railLeading,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
