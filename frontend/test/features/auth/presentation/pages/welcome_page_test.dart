import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/features/auth/presentation/pages/splash_page.dart';
import 'package:giliran/features/auth/presentation/pages/welcome_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: page,
    ),
  );
}

void main() {
  group('SplashPage', () {
    testWidgets('shows the wordmark and calls onReady after the hold', (
      tester,
    ) async {
      // Arrange
      var ready = 0;
      await _pumpPage(tester, SplashPage(onReady: () => ready++));

      // Act
      await tester.pump(SplashPage.minHold - const Duration(milliseconds: 1));
      final readyBeforeHold = ready;
      await tester.pump(const Duration(milliseconds: 1));

      // Assert
      expect(find.text('giliran'), findsOneWidget);
      expect(find.text('Arisan yang transparan'), findsOneWidget);
      expect(readyBeforeHold, 0);
      expect(ready, 1);
    });

    testWidgets('does not call onReady once disposed', (tester) async {
      // Arrange
      var ready = 0;
      await _pumpPage(tester, SplashPage(onReady: () => ready++));

      // Act
      await tester.pumpWidget(const SizedBox());
      await tester.pump(SplashPage.minHold);

      // Assert
      expect(ready, 0);
    });
  });

  group('WelcomePage', () {
    testWidgets('starts on page 1 with Lanjut and Lewati', (tester) async {
      // Arrange & Act
      await _pumpPage(tester, WelcomePage(onSignIn: () {}));

      // Assert
      expect(find.text('Lanjut'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Masuk dengan email'), findsNothing);
      expect(find.bySemanticsLabel('Halaman 1 dari 3'), findsOneWidget);
    });

    testWidgets('Lanjut steps to the next page', (tester) async {
      // Arrange
      await _pumpPage(tester, WelcomePage(onSignIn: () {}));

      // Act
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.bySemanticsLabel('Halaman 2 dari 3'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('Lewati jumps to the last page and shows sign-in', (
      tester,
    ) async {
      // Arrange
      var signIns = 0;
      await _pumpPage(tester, WelcomePage(onSignIn: () => signIns++));

      // Act
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk dengan email'));

      // Assert
      expect(find.bySemanticsLabel('Halaman 3 dari 3'), findsOneWidget);
      expect(find.text('Lewati'), findsNothing);
      expect(find.text('Lanjut'), findsNothing);
      expect(signIns, 1);
    });

    testWidgets('swiping changes the page', (tester) async {
      // Arrange
      await _pumpPage(tester, WelcomePage(onSignIn: () {}));

      // Act
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      // Assert
      expect(find.bySemanticsLabel('Halaman 2 dari 3'), findsOneWidget);
    });

    testWidgets('tablet shows all three points on one page', (tester) async {
      // Arrange & Act
      await _pumpPage(
        tester,
        WelcomePage(onSignIn: () {}),
        size: const Size(1280, 800),
      );

      // Assert
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(HeadlineText), findsNWidgets(3));
      expect(find.text('Masuk dengan email'), findsOneWidget);
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      // Arrange & Act
      await _pumpPage(tester, WelcomePage(onSignIn: () {}), dark: true);
      await tester.pumpAndSettle();

      // Assert
      expect(tester.takeException(), isNull);
      expect(find.byType(Illustration), findsWidgets);
    });
  });
}
