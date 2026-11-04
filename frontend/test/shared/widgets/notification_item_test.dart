import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/constants/app_icons.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  late List<String> calls;

  setUp(() => calls = []);

  Widget item({bool read = false}) => SizedBox(
    width: 360,
    child: NotificationItem(
      id: 'n1',
      icon: AppIcons.bellRinging,
      title: 'Iuran Arisan RT 05 jatuh tempo besok',
      body: 'Rp200.000 untuk periode 4',
      time: '19.30',
      groupName: 'Arisan RT 05',
      toneColor: const Color(0xFF2E7D5B),
      read: read,
      onTap: () => calls.add('tap'),
      onMarkRead: () => calls.add('read'),
    ),
  );

  testWidgets('shows the group line, title, body and time', (tester) async {
    // Act
    await tester.pumpApp(item());

    // Assert
    expect(find.text('Arisan RT 05'), findsOneWidget);
    expect(find.text('Iuran Arisan RT 05 jatuh tempo besok'), findsOneWidget);
    expect(find.text('Rp200.000 untuk periode 4'), findsOneWidget);
    expect(find.text('19.30'), findsOneWidget);
  });

  testWidgets('unread has a kunyit bar and a bold title; read has neither', (tester) async {
    // Arrange
    await tester.pumpApp(item());
    final colors = tester.element(find.byType(NotificationItem)).colors;
    bool hasBar() => tester.widgetList<ColoredBox>(find.byType(ColoredBox)).any((b) => b.color == colors.turn);
    FontWeight? titleWeight() =>
        tester.widget<Text>(find.text('Iuran Arisan RT 05 jatuh tempo besok')).style?.fontWeight;
    expect(hasBar(), isTrue);
    final unreadWeight = titleWeight();

    // Act
    await tester.pumpApp(item(read: true));

    // Assert
    expect(hasBar(), isFalse);
    expect(unreadWeight!.value, greaterThan(titleWeight()!.value));
  });

  testWidgets('swiping marks it read and keeps it in place', (tester) async {
    // Arrange
    await tester.pumpApp(item());

    // Act
    await tester.drag(find.byType(NotificationItem), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Assert
    expect(calls, ['read']);
    expect(find.byType(NotificationItem), findsOneWidget);
  });

  testWidgets('tapping opens it', (tester) async {
    // Arrange
    await tester.pumpApp(item());

    // Act
    await tester.tap(find.byType(NotificationItem));

    // Assert
    expect(calls, ['tap']);
  });

  testWidgets('reads "Belum dibaca" first while unread', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpApp(item());

    // Assert
    expect(
      find.bySemanticsLabel(RegExp(r'^Belum dibaca\. Iuran Arisan RT 05 jatuh tempo besok, Arisan RT 05')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
