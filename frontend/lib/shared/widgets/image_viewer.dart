import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// One image in an [ImageViewer]: a signed proof URL and who uploaded it
/// when.
class const ImageViewerPage({
  required final String url,
  final String? uploaderName,
  final String? caption,
}) {}

/// Full-screen image viewer (Tikar §8.22) for payment and payout proofs.
/// The background is always the dark viewer color so screenshots read
/// clearly. Pinch or double-tap zooms up to 4×; a swipe down closes it.
/// The top bar shows close, the uploader and time, and "2 dari 3" when
/// there are several [pages]. [bottom] docks content under the image, such
/// as the review actions.
class const ImageViewer({
  super.key,
  required final List<ImageViewerPage> pages,
  final int initialIndex = 0,
  required final VoidCallback onClose,
  final ValueChanged<int>? onPageChanged,
  final Widget? bottom,

  /// Shown instead of the image when [pages] is empty.
  final String? emptyText,
}) extends StatefulWidget {
  static const maxScale = 4.0;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState() extends State<ImageViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late final ValueNotifier<int> _index = ValueNotifier(widget.initialIndex);

  @override
  void dispose() {
    _pages.dispose();
    _index.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    _index.value = i;
    widget.onPageChanged?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pages = widget.pages;
    return ColoredBox(
      color: c.viewerBg,
      child: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _index,
              builder: (context, i, _) => _TopBar(
                page: pages.isEmpty ? null : pages[i.clamp(0, pages.length - 1)],
                index: i,
                count: pages.length,
                onClose: widget.onClose,
              ),
            ),
            Expanded(
              child: GestureDetector(
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 400) widget.onClose();
                },
                child: pages.isEmpty
                    ? _Empty(text: widget.emptyText ?? '')
                    : PageView.builder(
                        controller: _pages,
                        itemCount: pages.length,
                        onPageChanged: _onPage,
                        itemBuilder: (context, i) => _ZoomableImage(url: pages[i].url),
                      ),
              ),
            ),
            ?widget.bottom,
          ],
        ),
      ),
    );
  }
}

class const _TopBar({
  required final ImageViewerPage? page,
  required final int index,
  required final int count,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = AppTextStyles.of(context);
    const fg = AppPalette.cream;
    return SizedBox(
      height: AppSizes.topBarH,
      child: Row(
        children: [
          const SizedBox(width: AppSpace.s2),
          Pressable(
            onTap: onClose,
            shape: const CircleBorder(),
            semanticLabel: l10n.imageViewerClose,
            child: const SizedBox.square(
              dimension: AppSizes.tapMin,
              child: Center(
                child: AppIcon(AppIcons.x, size: AppSizes.iconLg, color: fg),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page?.uploaderName case final name?)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(color: fg),
                  ),
                if (page?.caption case final caption?)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: AppPalette.creamMuted),
                  ),
              ],
            ),
          ),
          if (count > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Semantics(
                liveRegion: true,
                child: Text(l10n.proofPageIndicator(index + 1, count), style: t.caption.copyWith(color: fg)),
              ),
            ),
        ],
      ),
    );
  }
}

/// One page: pinch to zoom up to 4×, double-tap to toggle 2.5×.
class const _ZoomableImage({required final String url}) extends StatefulWidget {
  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState() extends State<_ZoomableImage> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    final at = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: ImageViewer.maxScale,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (context, _) => const Center(child: CircularProgressIndicator(color: AppPalette.cream)),
            errorWidget: (context, _, _) => const Center(
              child: AppIcon(AppIcons.warningCircle, size: AppSizes.iconXl, color: AppPalette.creamMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class const _Empty({required final String text}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppTextStyles.of(context);
    return Center(
      child: Text(text, style: t.body.copyWith(color: AppPalette.creamMuted)),
    );
  }
}
