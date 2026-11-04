import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

const _tone = GroupTone(surface: AppPalette.pandan200, accent: AppPalette.pandan700);
const _hash = '9f2c4b1e7d3a8c6f0e5b2a9d4c7f1e3b8a6d2c5f9e0b7a4d1c8f3e6b2a5da71e';

void main() {
  final people = [for (var n = 1; n <= 8; n++) AvatarData(name: 'Anggota $n')];

  Future<void> pumpStage(
    WidgetTester tester, {
    bool reduced = false,
    VoidCallback? onDraw,
    VoidCallback? onCommitmentTap,
    bool showDrawButton = true,
    AvatarData? featured,
    String? hash = _hash,
    int shakeToken = 0,
  }) async {
    await tester.pumpApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: SingleChildScrollView(
          child: DrawStage(
            tone: _tone,
            people: people,
            featured: featured,
            commitmentHash: hash,
            onCommitmentTap: onCommitmentTap,
            showDrawButton: showDrawButton,
            onDraw: onDraw,
            onPeople: () {},
            onHelp: () {},
            shakeToken: shakeToken,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the short commitment and opens it on tap', (tester) async {
    // Arrange
    var opened = 0;
    await pumpStage(tester, onCommitmentTap: () => opened++);

    // Act
    await tester.tap(find.text('Kode komitmen 9f2c…a71e'));

    // Assert
    expect(opened, 1);
  });

  testWidgets('a null onDraw disables the Kocok button', (tester) async {
    // Arrange
    await pumpStage(tester);

    // Act
    final button = tester.widget<CircleIconButton>(
      find.byWidgetPredicate((w) => w is CircleIconButton && w.variant == CircleIconButtonVariant.draw),
    );

    // Assert
    expect(button.onPressed, isNull);
    expect(find.text('Kocok'), findsOneWidget);
  });

  testWidgets('members see no draw button', (tester) async {
    // Arrange
    await pumpStage(tester, showDrawButton: false);

    // Assert
    expect(find.text('Kocok'), findsNothing);
    expect(find.bySemanticsLabel('Lihat peserta'), findsOneWidget);
  });

  testWidgets('reduced motion shows a static grid instead of the orbit', (tester) async {
    // Arrange
    await pumpStage(tester, reduced: true);

    // Act
    await tester.pumpAndSettle();

    // Assert
    expect(find.descendant(of: find.byType(DrawStage), matching: find.byType(Wrap)), findsOneWidget);
    expect(find.byType(AppAvatar), findsNWidgets(people.length));
  });

  testWidgets('fixed order shows the next person and no commitment', (tester) async {
    // Arrange
    await pumpStage(tester, featured: const AvatarData(name: 'Pak Dedi'), hash: null);

    // Assert
    expect(find.text('Giliran berikutnya'), findsOneWidget);
    expect(find.text('Pak Dedi'), findsOneWidget);
    expect(find.textContaining('Kode komitmen'), findsNothing);
  });

  testWidgets('a new shake token fires three light haptics, even with reduced motion', (tester) async {
    // Arrange
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String?);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpStage(tester, reduced: true);

    // Act
    await pumpStage(tester, reduced: true, shakeToken: 1);
    await tester.pump(DrawStage.shakeDuration);

    // Assert
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
    ]);
  });
}
