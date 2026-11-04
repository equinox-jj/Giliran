import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/enums/photo_source.dart';
import 'adaptive/app_sheet.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// Upload tile (Tikar §8.21) for payment and payout proofs: a 4:3 area that
/// is empty (dashed, "Pilih bukti transfer"), selected (the picked image,
/// remove and "Ganti"), uploading (dimmed, progress bar), failed (bata
/// border, [errorText], "Coba lagi") or [done] (paid check badge).
///
/// Tapping an empty tile, or "Ganti", opens the Kamera / Galeri sheet and
/// reports the choice through [onPick].
class const UploadTile({
  super.key,

  /// The picked file on this device.
  final String? localPath,

  /// Sent fraction (0–1) while uploading.
  final double? progress,
  final String? errorText,
  final bool done = false,
  required final ValueChanged<PhotoSource>? onPick,
  final VoidCallback? onRemove,
  final VoidCallback? onRetry,
}) extends StatelessWidget {
  bool get _uploading => progress != null;

  Future<void> _choose(BuildContext context) async {
    final source = await showUploadSourceSheet(context);
    if (source != null) onPick?.call(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final path = localPath;
    final failed = errorText != null && !_uploading;
    final canChange = onPick != null && !_uploading && !done;

    final Widget area;
    if (path == null) {
      area = _EmptyArea(onTap: onPick == null ? null : () => _choose(context));
    } else {
      area = ClipPath(
        clipper: ShapeBorderClipper(shape: AppShapes.squircle(AppRadius.lg)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: _uploading ? 0.6 : 1,
              child: Image.file(File(path), fit: BoxFit.cover, semanticLabel: l10n.uploadSourceTitle),
            ),
            if (failed)
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: AppShapes.squircle(
                    AppRadius.lg,
                    side: BorderSide(color: c.rejected.fg, width: AppStroke.strong),
                  ),
                ),
              ),
            if (_uploading) _Progress(value: progress!),
            if (done) const PositionedDirectional(top: AppSpace.s2, start: AppSpace.s2, child: _DoneBadge()),
            if (canChange && onRemove != null)
              PositionedDirectional(
                top: AppSpace.s2,
                end: AppSpace.s2,
                child: _RemoveButton(onPressed: onRemove!),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(aspectRatio: 4 / 3, child: area),
        if (failed) ...[
          const SizedBox(height: AppSpace.s2),
          _Failure(message: errorText!, onRetry: onRetry),
        ] else if (path != null && canChange)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: l10n.uploadTileChange,
              variant: AppButtonVariant.link,
              size: AppButtonSize.small,
              onPressed: () => _choose(context),
            ),
          ),
      ],
    );
  }
}

/// Opens the proof source sheet: Kamera / Galeri.
Future<PhotoSource?> showUploadSourceSheet(BuildContext context) {
  final l10n = context.l10n;
  return showAppSheet<PhotoSource>(
    context,
    builder: (context) => AppSheetBody(
      title: l10n.uploadSourceTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceRow(icon: AppIcons.camera, label: l10n.uploadSourceCamera, source: PhotoSource.camera),
          _SourceRow(icon: AppIcons.image, label: l10n.uploadSourceGallery, source: PhotoSource.gallery),
        ],
      ),
    ),
  );
}

class const _EmptyArea({required final VoidCallback? onTap}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Pressable(
      onTap: onTap,
      shape: AppShapes.squircle(AppRadius.lg),
      semanticLabel: '${l10n.uploadTileEmpty}. ${l10n.uploadTileHint}',
      child: DashedBorder(
        color: c.borderStrong,
        radius: AppRadius.lg,
        child: Center(
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.uploadSimple, size: AppSizes.iconXl, color: c.textSecondary),
                const SizedBox(height: AppSpace.s2),
                Text(l10n.uploadTileEmpty, style: t.label.copyWith(color: c.textPrimary)),
                const SizedBox(height: AppSpace.s1),
                Text(l10n.uploadTileHint, style: t.caption.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class const _Progress({required final double value}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final percent = (value.clamp(0.0, 1.0) * 100).round();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Semantics(
        liveRegion: true,
        value: l10n.uploadTileProgress(percent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.s2),
              child: Text(
                l10n.uploadTileProgress(percent),
                style: t.caption.copyWith(
                  color: c.textOnInverse,
                  shadows: [Shadow(color: c.scrim, blurRadius: 4)],
                ),
              ),
            ),
            LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 4,
              color: c.ink,
              backgroundColor: c.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class const _DoneBadge() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: context.l10n.uploadTileDone,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s1),
        decoration: ShapeDecoration(color: c.paid.bg, shape: const CircleBorder()),
        child: AppIcon(AppIcons.checkCircleFill, size: AppSizes.iconMd, color: c.paid.fg),
      ),
    );
  }
}

class const _RemoveButton({required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onPressed,
      shape: const CircleBorder(),
      hitPadding: const EdgeInsets.all(AppSpace.s1),
      semanticLabel: context.l10n.uploadTileRemove,
      child: Container(
        width: AppSizes.circleAction,
        height: AppSizes.circleAction,
        decoration: ShapeDecoration(color: c.surfaceRaised, shape: const CircleBorder()),
        child: Center(
          child: AppIcon(AppIcons.x, size: AppSizes.iconMd, color: c.textPrimary),
        ),
      ),
    );
  }
}

class const _Failure({required final String message, required final VoidCallback? onRetry}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Row(
      children: [
        AppIcon(AppIcons.warningCircle, size: AppSizes.iconMd, color: c.rejected.fg),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(message, style: t.caption.copyWith(color: c.rejected.fg)),
          ),
        ),
        if (onRetry != null)
          AppButton(
            label: context.l10n.commonRetry,
            variant: AppButtonVariant.link,
            size: AppButtonSize.small,
            onPressed: onRetry,
          ),
      ],
    );
  }
}

class const _SourceRow({
  required final String icon,
  required final String label,
  required final PhotoSource source,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Pressable(
      onTap: () => Navigator.of(context).pop(source),
      shape: AppShapes.squircle(AppRadius.md),
      child: SizedBox(
        height: AppSizes.settingsRowH,
        child: Row(
          children: [
            const SizedBox(width: AppSpace.s2),
            AppIcon(icon, size: AppSizes.iconLg, color: c.textSecondary),
            const SizedBox(width: AppSpace.s4),
            Text(label, style: t.label.copyWith(color: c.textPrimary)),
          ],
        ),
      ),
    );
  }
}
