import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/services/widget_image_exporter.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('exports the Bukti Kocok frame as a 1080 × 1350 PNG', (tester) async {
    // Arrange
    late BuildContext context;
    await tester.pumpApp(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final ticket = BuktiKocokTicket(
      groupName: 'Arisan RT 05',
      periodNo: 4,
      totalPeriods: 10,
      slotNo: 7,
      winnerName: 'Bu Rina',
      drawnAt: DateTime.utc(2026, 10, 26, 12, 30),
      code: '7H2K9QX4MP',
      verifyUrl: 'https://giliran.monai.my.id/v/7H2K9QX4MP',
    );

    // Act
    final png = await tester.runAsync(
      () => const WidgetImageExporter().export(
        BuktiKocokExportFrame(ticket: ticket),
        logicalSize: BuktiKocokExportFrame.size,
        pixelRatio: BuktiKocokExportFrame.pixelRatio,
        inherit: context,
      ),
    );
    final image = await tester.runAsync(() => decodeImageFromList(png!));

    // Assert
    expect(png!.sublist(0, 4), [137, 80, 78, 71]);
    expect(image!.width, 1080);
    expect(image.height, 1350);
    expect(AppTheme.light(), isNotNull);
  });
}
