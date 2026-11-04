import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_image_exporter.g.dart';

/// Renders a widget that is not on screen into PNG bytes, for shareable
/// images such as the Bukti Kocok ticket (1080 × 1350).
///
/// Pass the screen's [BuildContext] as `inherit` so the image gets the
/// app's theme and localizations; the widget is laid out at [logicalSize]
/// and painted at [pixelRatio].
class const WidgetImageExporter() {
  Future<Uint8List> export(
    Widget widget, {
    required Size logicalSize,
    double pixelRatio = 3,
    BuildContext? inherit,
  }) async {
    var child = widget;
    if (inherit != null) {
      child = Localizations.override(context: inherit, child: InheritedTheme.captureAll(inherit, child));
    }
    child = MediaQuery(
      data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView ?? ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: SizedBox.fromSize(size: logicalSize, child: child),
    ).attachToRenderTree(buildOwner);
    try {
      buildOwner
        ..buildScope(root)
        ..finalizeTree();
      pipeline
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      // Unmount the off-screen tree so its elements and tickers are freed.
      RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(buildOwner, root);
      buildOwner
        ..buildScope(root)
        ..finalizeTree();
    }
  }
}

@Riverpod(keepAlive: true)
WidgetImageExporter widgetImageExporter(Ref ref) => const WidgetImageExporter();
