import '../../core/l10n/l10n.dart';

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/themes/themes.dart';
import 'adaptive/app_sheet.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// What the user chose in [showAvatarSourceSheet].
enum AvatarSheetAction() {
  camera,
  gallery,
  remove,
}

/// Opens the "Foto profil" sheet: Kamera / Galeri, plus "Hapus foto" when
/// [canRemove].
Future<AvatarSheetAction?> showAvatarSourceSheet(
  BuildContext context, {
  bool canRemove = false,
}) {
  return showAppSheet<AvatarSheetAction>(
    context,
    builder: (context) => AppSheetBody(
      title: context.l10n.widgetProfilePhoto,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetRow(
            icon: AppIcons.camera,
            label: context.l10n.uploadSourceCamera,
            action: AvatarSheetAction.camera,
          ),
          _SheetRow(
            icon: AppIcons.image,
            label: context.l10n.uploadSourceGallery,
            action: AvatarSheetAction.gallery,
          ),
          if (canRemove)
            _SheetRow(
              icon: AppIcons.trash,
              label: context.l10n.uploadTileRemove,
              action: AvatarSheetAction.remove,
              destructive: true,
            ),
        ],
      ),
    ),
  );
}

class const _SheetRow({
  required final String icon,
  required final String label,
  required final AvatarSheetAction action,
  final bool destructive = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final color = destructive ? c.rejected.fg : c.textPrimary;

    return Pressable(
      onTap: () => Navigator.of(context).pop(action),
      shape: AppShapes.squircle(AppRadius.md),
      child: SizedBox(
        height: AppSizes.settingsRowH,
        child: Row(
          children: [
            const SizedBox(width: AppSpace.s2),
            AppIcon(
              icon,
              size: AppSizes.iconLg,
              color: destructive ? color : c.textSecondary,
            ),
            const SizedBox(width: AppSpace.s4),
            Text(label, style: t.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class const AvatarPicker({
  super.key,

  /// The picked file on this device; wins over [imageUrl].
  final String? localPath,
  final String? imageUrl,

  /// Sent fraction (0–1) while uploading.
  final double? progress,

  /// Why the upload failed; shows the bata ring and "Coba lagi".
  final String? errorText,
  final bool done = false,
  required final VoidCallback? onTap,
  final VoidCallback? onRetry,
  final double size = AppSizes.avatarXl,
}) extends StatelessWidget {
  bool get _hasPhoto => localPath != null || (imageUrl?.isNotEmpty ?? false);
  bool get _uploading => progress != null;

  @override
  Widget build(BuildContext context) {
    final semantic = _uploading
        ? context.l10n.widgetAvatarUploading((progress! * 100).round())
        : _hasPhoto
        ? context.l10n.widgetAvatarChange
        : context.l10n.widgetAvatarAdd;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: _uploading ? null : onTap,
          shape: const CircleBorder(),
          semanticLabel: semantic,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _hasPhoto
                      ? _Photo(
                          localPath: localPath,
                          imageUrl: imageUrl,
                          dimmed: _uploading,
                          failed: errorText != null,
                        )
                      : const _EmptyCircle(),
                ),
                if (_uploading) Positioned.fill(child: _ProgressRing(value: progress!)),
                if (done)
                  const Positioned(
                    left: -2,
                    top: -2,
                    child: _DoneBadge(),
                  ),
                if (!_uploading)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: _EditBadge(icon: _hasPhoto ? AppIcons.pencilSimple : AppIcons.camera),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        _Caption(
          uploading: _uploading,
          percent: ((progress ?? 0) * 100).round(),
          hasPhoto: _hasPhoto,
          errorText: errorText,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class const _EmptyCircle() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return DashedBorder.circle(
      color: c.borderStrong,
      strokeWidth: AppStroke.regular,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.subtle, shape: BoxShape.circle),
        child: Center(
          child: AppIcon(
            AppIcons.uploadSimple,
            size: AppSizes.iconXl,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// The picked or uploaded photo, cover-fit in the circle.
class const _Photo({
  required final String? localPath,
  required final String? imageUrl,
  required final bool dimmed,
  required final bool failed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = ColoredBox(color: c.subtle);
    final Widget image = localPath != null
        ? Image.file(
            File(localPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          );

    return Container(
      decoration: BoxDecoration(
        color: c.subtle,
        shape: BoxShape.circle,
        border: failed ? Border.all(color: c.rejected.fg, width: AppStroke.ink) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: image,
      ),
    );
  }
}

class const _ProgressRing({required final double value}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return CircularProgressIndicator(
      value: value > 0 ? value : null,
      strokeWidth: 3,
      color: c.ink,
      backgroundColor: c.subtle,
    );
  }
}

/// Bottom-right ink badge: camera when empty, pencil once there is a photo.
class const _EditBadge({required final String icon}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: c.inverse,
        shape: BoxShape.circle,
        border: Border.all(color: c.page, width: AppStroke.ink),
      ),
      alignment: Alignment.center,
      child: AppIcon(icon, size: AppSizes.iconSm, color: c.textOnInverse),
    );
  }
}

/// Top-left `CheckCircle` in the paid colors once the server has the photo.
class const _DoneBadge() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(color: c.paid.bg, shape: BoxShape.circle),
      child: AppIcon(AppIcons.checkCircleFill, size: 22, color: c.paid.fg),
    );
  }
}

class const _Caption({
  required final bool uploading,
  required final int percent,
  required final bool hasPhoto,
  required final String? errorText,
  required final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);

    if (errorText != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.warningCircle, size: AppSizes.iconSm, color: c.rejected.fg),
              const SizedBox(width: AppSpace.s1),
              Flexible(
                child: Text(
                  errorText!,
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(color: c.rejected.fg),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            AppButton.link(
              label: context.l10n.commonRetry,
              size: AppButtonSize.xsmall,
              onPressed: onRetry,
            ),
        ],
      );
    }

    final text = uploading
        ? context.l10n.widgetAvatarUploadingShort(percent)
        : hasPhoto
        ? context.l10n.widgetAvatarTapToChange
        : context.l10n.widgetAvatarOptional;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: t.caption.copyWith(color: c.textSecondary),
    );
  }
}
