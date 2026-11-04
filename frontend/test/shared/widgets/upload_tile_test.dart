import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/photo_source.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  late String imagePath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('upload_tile');
    // A 1×1 transparent PNG.
    imagePath = (File('${dir.path}/proof.png')..writeAsBytesSync(_png)).path;
  });

  testWidgets('empty: tapping opens Kamera / Galeri and reports the choice', (tester) async {
    // Arrange
    final picked = <PhotoSource>[];
    await tester.pumpApp(SizedBox(width: 320, child: UploadTile(onPick: picked.add)));

    // Act
    await tester.tap(find.text('Pilih bukti transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('JPG/PNG, maks 5 MB'), findsOneWidget);
    expect(picked, [PhotoSource.gallery]);
  });

  testWidgets('selected: shows Ganti and a remove button', (tester) async {
    // Arrange
    var removed = 0;
    await tester.pumpApp(
      SizedBox(
        width: 320,
        child: UploadTile(localPath: imagePath, onPick: (_) {}, onRemove: () => removed++),
      ),
    );

    // Act
    await tester.tap(find.bySemanticsLabel('Hapus foto'));

    // Assert
    expect(find.text('Ganti'), findsOneWidget);
    expect(removed, 1);
  });

  testWidgets('uploading: shows the percentage and hides Ganti', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 320,
        child: UploadTile(localPath: imagePath, progress: 0.42, onPick: (_) {}),
      ),
    );

    // Assert
    expect(find.text('42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Ganti'), findsNothing);
  });

  testWidgets('failed: shows the error and Coba lagi', (tester) async {
    // Arrange
    var retries = 0;
    await tester.pumpApp(
      SizedBox(
        width: 320,
        child: UploadTile(
          localPath: imagePath,
          errorText: 'Ukuran maksimal 5 MB',
          onPick: (_) {},
          onRetry: () => retries++,
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Coba lagi'));

    // Assert
    expect(find.text('Ukuran maksimal 5 MB'), findsOneWidget);
    expect(retries, 1);
  });

  testWidgets('done: shows the check badge', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 320,
        child: UploadTile(localPath: imagePath, done: true, onPick: (_) {}),
      ),
    );

    // Assert
    expect(find.bySemanticsLabel('Bukti terunggah'), findsOneWidget);
    expect(find.text('Ganti'), findsNothing);
  });
}

const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
