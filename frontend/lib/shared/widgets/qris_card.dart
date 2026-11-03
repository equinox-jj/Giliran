import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'dashed_border.dart';
import 'pressable.dart';

/// The organizer's QRIS (Tikar §8.20): the image on a white square (scanners
/// need a light background, even in dark mode), the merchant name and the
/// "checked" caption. The organizer gets an "Upload QRIS" tile when there is
/// none, replace and remove actions, and the server's validation error
/// inline under the card.
class const QrisCard({
  super.key,

  /// Short-lived signed URL; null while only the cache knows a QRIS exists.
  final String? imageUrl,
  final String? merchantName,
  final bool hasQris = false,
  final VoidCallback? onUpload,
  final VoidCallback? onRemove,
  final VoidCallback? onEnlarge,
  final VoidCallback? onSaveImage,
  final bool uploading = false,
  final String? errorText,

  /// The organizer's editing layout (S15): a 112 px image beside the name,
  /// the "checked" line and Ganti / Hapus.
  final bool inline = false,
}) extends StatelessWidget {
  static const maxImage = 240.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasQris && inline)
          _InlineQrisCard(
            imageUrl: imageUrl,
            merchantName: merchantName,
            onReplace: onUpload,
            onRemove: onRemove,
            uploading: uploading,
          )
        else if (hasQris)
          _QrisImageCard(
            imageUrl: imageUrl,
            merchantName: merchantName,
            onReplace: onUpload,
            onRemove: onRemove,
            onEnlarge: onEnlarge,
            onSaveImage: onSaveImage,
            uploading: uploading,
          )
        else if (onUpload != null)
          _UploadTile(onUpload: onUpload!, uploading: uploading, failed: error != null),
        if (error != null) ...[
          const SizedBox(height: AppSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(AppIcons.warningCircle, size: AppSizes.iconSm, color: c.rejected.fg),
              const SizedBox(width: AppSpace.s1),
              Expanded(
                child: Text(error, style: t.caption.copyWith(color: c.rejected.fg)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class const _QrisImageCard({
  required final String? imageUrl,
  required final String? merchantName,
  required final VoidCallback? onReplace,
  required final VoidCallback? onRemove,
  required final VoidCallback? onEnlarge,
  required final VoidCallback? onSaveImage,
  required final bool uploading,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final url = imageUrl;
    final name = merchantName ?? '';
    return AppCard(
      style: AppCardStyle.outlined,
      child: Column(
        children: [
          Semantics(
            image: true,
            label: l10n.qrisImageSemantics(name),
            child: Container(
              constraints: const BoxConstraints(maxWidth: QrisCard.maxImage, maxHeight: QrisCard.maxImage),
              padding: const EdgeInsets.all(AppSpace.s3),
              decoration: ShapeDecoration(
                // Fixed white in both themes so scanners can read the code.
                color: AppPalette.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: url == null || uploading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          if (name.isNotEmpty)
            Text(
              name,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: c.textPrimary),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppIcons.sealCheckFill, size: AppSizes.iconSm, color: c.paid.fg),
              const SizedBox(width: AppSpace.s1),
              Text(l10n.qrisValidated, style: t.caption.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              if (onSaveImage != null)
                AppButton.secondary(label: l10n.qrisSaveImage, size: AppButtonSize.xsmall, onPressed: onSaveImage),
              if (onEnlarge != null)
                AppButton.secondary(label: l10n.qrisEnlarge, size: AppButtonSize.xsmall, onPressed: onEnlarge),
              if (onReplace != null)
                AppButton.secondary(label: l10n.qrisReplace, size: AppButtonSize.xsmall, onPressed: onReplace),
              if (onRemove != null)
                AppButton.secondary(label: l10n.qrisRemove, size: AppButtonSize.xsmall, onPressed: onRemove),
            ],
          ),
        ],
      ),
    );
  }
}

class const _InlineQrisCard({
  required final String? imageUrl,
  required final String? merchantName,
  required final VoidCallback? onReplace,
  required final VoidCallback? onRemove,
  required final bool uploading,
}) extends StatelessWidget {
  static const _image = 112.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final l10n = context.l10n;
    final url = imageUrl;
    final name = merchantName ?? '';
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: ShapeDecoration(color: c.surface, shape: AppShapes.squircle(AppRadius.lg)),
      child: Row(
        children: [
          Semantics(
            image: true,
            label: l10n.qrisImageSemantics(name),
            child: Container(
              width: _image,
              height: _image,
              padding: const EdgeInsets.all(10),
              decoration: ShapeDecoration(
                // Fixed white in both themes so scanners can read the code.
                color: AppPalette.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  side: BorderSide(color: c.hairline, width: 1),
                ),
              ),
              child: url == null || uploading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty) Text(name, style: t.title.copyWith(fontSize: 15, color: c.textPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AppIcon(AppIcons.sealCheck, size: AppSizes.iconSm, color: c.paid.fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.qrisValidated,
                        style: t.caption.copyWith(color: c.paid.fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (onReplace != null)
                      AppButton.secondary(label: l10n.qrisReplace, size: AppButtonSize.xsmall, onPressed: onReplace),
                    if (onRemove != null) _RemoveButton(label: l10n.qrisRemove, onPressed: onRemove!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Hapus" as plain `rejected.fg` text, as drawn on S15.
class const _RemoveButton({required final String label, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppTextStyles.of(context);
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      shape: AppShapes.pill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: t.label.copyWith(fontSize: 13, color: context.colors.rejected.fg)),
          ),
        ),
      ),
    );
  }
}

class const _UploadTile({
  required final VoidCallback onUpload,
  required final bool uploading,
  required final bool failed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final label = context.l10n.qrisUpload;
    return Center(
      child: Pressable(
        onTap: uploading ? null : onUpload,
        semanticLabel: label,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: SizedBox.square(
          dimension: 200,
          child: DashedBorder(
            color: failed ? c.rejected.fg : c.borderStrong,
            radius: AppRadius.lg,
            child: Center(
              child: uploading
                  ? const CircularProgressIndicator.adaptive()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIcons.qrCode, size: AppSizes.iconXl, color: c.textPrimary),
                        const SizedBox(height: AppSpace.s2),
                        ExcludeSemantics(
                          child: Text(label, style: t.label.copyWith(color: c.textPrimary)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
