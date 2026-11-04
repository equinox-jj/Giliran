import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  const pages = [
    ImageViewerPage(url: 'https://files.test/a.jpg', uploaderName: 'Pak Dedi', caption: 'Kemarin, 19.02'),
    ImageViewerPage(url: 'https://files.test/b.jpg', uploaderName: 'Pak Dedi'),
  ];

  testWidgets('shows the uploader and the page indicator for several proofs', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox.expand(
        child: ImageViewer(pages: pages, onClose: () {}),
      ),
    );

    // Assert
    expect(find.text('Pak Dedi'), findsOneWidget);
    expect(find.text('Kemarin, 19.02'), findsOneWidget);
    expect(find.text('1 dari 2'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('the close button closes it', (tester) async {
    // Arrange
    var closed = 0;
    await tester.pumpApp(
      SizedBox.expand(
        child: ImageViewer(pages: pages, onClose: () => closed++),
      ),
    );

    // Act
    await tester.tap(find.bySemanticsLabel('Tutup'));

    // Assert
    expect(closed, 1);
  });

  testWidgets('a swipe down closes it', (tester) async {
    // Arrange
    var closed = 0;
    await tester.pumpApp(
      SizedBox.expand(
        child: ImageViewer(pages: pages, onClose: () => closed++),
      ),
    );

    // Act
    await tester.fling(find.byType(PageView), const Offset(0, 400), 1500);
    await tester.pump();

    // Assert
    expect(closed, 1);
  });

  testWidgets('without pages it shows the empty text', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox.expand(
        child: ImageViewer(pages: const [], onClose: () {}, emptyText: 'Belum ada bukti.'),
      ),
    );

    // Assert
    expect(find.text('Belum ada bukti.'), findsOneWidget);
    expect(find.text('1 dari 2'), findsNothing);
  });

  testWidgets('the background stays dark in the light theme', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox.expand(
        child: ImageViewer(pages: pages, onClose: () {}),
      ),
    );

    // Assert
    final box = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(ImageViewer), matching: find.byType(ColoredBox)).first,
    );
    expect(box.color, const Color(0xFF15110D));
  });
}
