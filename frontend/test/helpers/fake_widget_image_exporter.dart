import 'dart:typed_data';

import 'package:giliran/core/services/widget_image_exporter.dart';
import 'package:material_ui/material_ui.dart';

/// Returns fixed bytes instead of rendering, and records each export.
class FakeWidgetImageExporter() implements WidgetImageExporter {
  final exports = <({Widget widget, Size logicalSize, double pixelRatio})>[];
  Uint8List bytes = Uint8List.fromList([137, 80, 78, 71]);

  @override
  Future<Uint8List> export(
    Widget widget, {
    required Size logicalSize,
    double pixelRatio = 3,
    BuildContext? inherit,
  }) async {
    exports.add((widget: widget, logicalSize: logicalSize, pixelRatio: pixelRatio));
    return bytes;
  }
}
