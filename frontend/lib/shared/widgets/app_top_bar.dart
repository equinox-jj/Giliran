import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'avatar.dart';
import 'circle_icon_button.dart';

/// Watches the nearest scrollable under the [Scaffold] and reports whether
/// content has scrolled under the bar (and by how much).
mixin _ScrolledUnder<T extends StatefulWidget> on State<T> {
  ScrollNotificationObserverState? _observer;
  double scrollOffset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification || n.depth != 0) return;
    if (n.metrics.axis != Axis.vertical) return;
    final offset = n.metrics.extentBefore;
    if ((offset > 0) != (scrollOffset > 0) || (offset < 64 || scrollOffset < 64)) {
      setState(() => scrollOffset = offset);
    }
  }
}

/// Compact top app bar: 64 high on `bg.page`, a circle back button (or close
/// on modal screens), a centered `title`, up to two circle actions. A 1 px
/// hairline fades in when content scrolls under it.
///
/// For the headline variant set [collapseTitle]: the title stays hidden
/// until the [HeadlineBlock] below scrolls away.
class AppTopBar extends StatefulWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.actions = const [],
    this.leading,
    this.modal = false,
    this.showBack = true,
    this.collapseTitle = false,
    this.onBack,
  }) : assert(actions.length <= 2, 'At most two circle actions');

  final String? title;
  final List<Widget> actions;

  /// Replaces the back / close button.
  final Widget? leading;

  /// Shows `X` instead of `ArrowLeft` (create group, upload proof, review).
  final bool modal;
  final bool showBack;
  final bool collapseTitle;

  /// Defaults to `Navigator.maybePop`, which keeps the native iOS swipe and
  /// Android predictive back working.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.topBarH);

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> with _ScrolledUnder {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final margin = context.screenMargin - 2;

    final leading =
        widget.leading ??
        (widget.showBack && (canPop || widget.onBack != null)
            ? CircleIconButton(
                icon: widget.modal ? AppIcons.x : AppIcons.arrowLeft,
                semanticLabel: widget.modal ? 'Tutup' : 'Kembali',
                onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null);

    final titleVisible = !widget.collapseTitle || scrollOffset > 48;

    return Material(
      color: c.page,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SizedBox(
              height: AppSizes.topBarH,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: NavigationToolbar(
                  leading: leading,
                  middle: widget.title == null
                      ? null
                      : AnimatedOpacity(
                          opacity: titleVisible ? 1 : 0,
                          duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.base,
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.title!,
                              style: t.title.copyWith(color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  trailing: widget.actions.isEmpty
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.actions,
                        ),
                  middleSpacing: AppSpace.s2,
                ),
              ),
            ),
            _Hairline(visible: scrollOffset > 0),
          ],
        ),
      ),
    );
  }
}

/// Greeting bar (Beranda only): 72 high, avatar 48 + "Halo, {first name}"
/// + a caption, and the bell with a bata dot when there is unread activity.
class GreetingTopBar extends StatefulWidget implements PreferredSizeWidget {
  const GreetingTopBar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.subtitle,
    this.unread = false,
    this.unreadCount,
    this.onBell,
    this.onAvatar,
  });

  final String name;
  final String? avatarUrl;

  /// e.g. "3 arisan aktif".
  final String? subtitle;
  final bool unread;
  final int? unreadCount;
  final VoidCallback? onBell;
  final VoidCallback? onAvatar;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.greetingBarH);

  @override
  State<GreetingTopBar> createState() => _GreetingTopBarState();
}

class _GreetingTopBarState extends State<GreetingTopBar> with _ScrolledUnder {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final firstName = widget.name.trim().split(RegExp(r'\s+')).first;

    return Material(
      color: c.page,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SizedBox(
              height: AppSizes.greetingBarH,
              child: Padding(
                padding: EdgeInsets.only(
                  left: context.screenMargin,
                  right: context.screenMargin - 2,
                ),
                child: Row(
                  children: [
                    Semantics(
                      button: widget.onAvatar != null,
                      label: 'Profil',
                      child: GestureDetector(
                        onTap: widget.onAvatar,
                        child: AppAvatar(
                          name: widget.name,
                          imageUrl: widget.avatarUrl,
                          size: 48,
                          semanticLabel: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, $firstName',
                            style: t.title.copyWith(color: c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: t.caption.copyWith(color: c.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: AppIcons.bellSimple,
                      semanticLabel: widget.unreadCount != null && widget.unreadCount! > 0
                          ? 'Notifikasi, ${widget.unreadCount} belum dibaca'
                          : 'Notifikasi',
                      showDot: widget.unread,
                      onPressed: widget.onBell,
                    ),
                  ],
                ),
              ),
            ),
            _Hairline(visible: scrollOffset > 0),
          ],
        ),
      ),
    );
  }
}

/// Drawn over the bar's bottom edge so it doesn't add to `preferredSize`.
/// Fades in once content scrolls under the bar.
class _Hairline extends StatelessWidget {
  const _Hairline({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppMotion.base,
      child: Container(height: 1, color: context.colors.hairline),
    ),
  );
}
