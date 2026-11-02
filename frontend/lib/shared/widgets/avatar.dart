import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'dashed_border.dart';

/// Member avatar: the photo when [imageUrl] is set, otherwise initials on the
/// group [tone] (pandan outside a group). Guests get a dashed ring and a
/// `UserCircleDashed` badge; organizers a kunyit crown badge.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AppSizes.avatarMd,
    this.tone,
    this.guest = false,
    this.organizer = false,
    this.ringColor,
    this.semanticLabel,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final GroupTone? tone;
  final bool guest;
  final bool organizer;

  /// Optional 2 px ring (avatar stacks use the page color).
  final Color? ringColor;

  /// Defaults to [name]; pass an empty string to make it decorative.
  final String? semanticLabel;

  /// Returns the uppercase initials of the first two words of [name], or `?` when
  /// [name] is blank.
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final second = words.length > 1 ? words[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = guest ? c.subtle : tone?.surface ?? (dark ? AppPalette.pandan800 : AppPalette.pandan100);

    final initialsText = Center(
      child: Text(
        initials(name),
        style: t.label.copyWith(
          color: guest ? c.textSecondary : c.textPrimary,
          fontSize: (size * 0.36).clamp(10.0, 28.0),
          height: 1,
        ),
      ),
    );

    Widget face = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl!.isEmpty
          ? initialsText
          : CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => initialsText,
              errorWidget: (_, _, _) => initialsText,
            ),
    );

    if (guest) {
      face = DashedBorder.circle(
        color: c.borderStrong,
        child: Padding(padding: const EdgeInsets.all(2), child: face),
      );
    }

    if (ringColor != null) {
      face = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
        child: face,
      );
    }

    final badgeSize = size >= AppSizes.avatarLg ? 18.0 : 16.0;
    Widget? badge;
    if (organizer) {
      badge = Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: c.turn,
          shape: BoxShape.circle,
          border: Border.all(color: c.ink, width: AppStroke.ink),
        ),
        alignment: Alignment.center,
        child: AppIcon(AppIcons.crownFill, size: badgeSize * 0.6, color: c.ink),
      );
    } else if (guest) {
      badge = Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(color: c.page, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(
          AppIcons.userCircleDashed,
          size: badgeSize,
          color: c.textSecondary,
        ),
      );
    }

    final label = semanticLabel ?? name;
    final avatar = badge == null || size < AppSizes.avatarMd
        ? face
        : Stack(
            clipBehavior: Clip.none,
            children: [
              face,
              Positioned(right: -2, bottom: -2, child: badge),
            ],
          );

    return Semantics(
      label: label.isEmpty ? null : label,
      image: label.isNotEmpty,
      excludeSemantics: true,
      child: avatar,
    );
  }
}

/// A person in an [AvatarStack].
class AvatarData {
  const AvatarData({required this.name, this.imageUrl, this.guest = false});

  final String name;
  final String? imageUrl;
  final bool guest;
}

/// Up to [max] avatars overlapping by 30%, each with a 2 px page ring, then a
/// "+N" chip.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.size = AppSizes.avatarSm,
    this.max = 4,
    this.tone,
    this.ringColor,
  });

  final List<AvatarData> people;
  final double size;
  final int max;
  final GroupTone? tone;

  /// Defaults to the page color; use the surface color on cards.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final ring = ringColor ?? c.page;
    final shown = people.take(max).toList();
    final extra = people.length - shown.length;
    final outer = size + 4;
    final step = outer * 0.7;
    final count = shown.length + (extra > 0 ? 1 : 0);

    return Semantics(
      label: '${people.length} orang',
      excludeSemantics: true,
      child: SizedBox(
        height: outer,
        width: count == 0 ? 0 : step * (count - 1) + outer,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: step * i,
                child: AppAvatar(
                  name: shown[i].name,
                  imageUrl: shown[i].imageUrl,
                  guest: shown[i].guest,
                  size: size,
                  tone: tone,
                  ringColor: ring,
                  semanticLabel: '',
                ),
              ),
            if (extra > 0)
              Positioned(
                left: step * shown.length,
                child: Container(
                  width: outer,
                  height: outer,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: ring,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.subtle,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$extra',
                      style: t.micro.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
