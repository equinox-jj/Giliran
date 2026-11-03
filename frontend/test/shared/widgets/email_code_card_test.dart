import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  // In the past, so the resend button shows and no countdown ticks.
  final resendOpen = DateTime(2020);

  Future<void> pumpCard(
    WidgetTester tester, {
    EmailCodeCardState state = EmailCodeCardState.waiting,
    String? message,
    DateTime? resendAvailableAt,
    ValueChanged<String>? onCompleted,
    VoidCallback? onChangeEmail,
    VoidCallback? onResend,
    VoidCallback? onRequestNew,
    VoidCallback? onRestart,
    Widget? pinStep,
    VoidCallback? onOpenMail,
  }) => tester.pumpApp(
    SingleChildScrollView(
      child: EmailCodeCard(
        emailMasked: 'ri•••••@gmail.com',
        state: state,
        message: message,
        resendAvailableAt: resendAvailableAt ?? resendOpen,
        onCompleted: onCompleted ?? (_) {},
        onChangeEmail: onChangeEmail,
        onResend: onResend,
        onRequestNew: onRequestNew,
        onRestart: onRestart,
        pinStep: pinStep,
        onOpenMail: onOpenMail,
      ),
    ),
  );

  testWidgets('shows the masked address and completes a typed code', (tester) async {
    // Arrange
    String? code;
    await pumpCard(tester, onCompleted: (v) => code = v);

    // Act
    await tester.enterText(find.byType(TextField), '482913');
    await tester.pump();

    // Assert
    expect(find.text('Masukkan kode dari email'), findsOneWidget);
    expect(find.text('Dikirim ke ri•••••@gmail.com'), findsOneWidget);
    expect(code, '482913');
  });

  testWidgets('Ubah and Kirim ulang call back', (tester) async {
    // Arrange
    var changed = 0;
    var resent = 0;
    await pumpCard(
      tester,
      onChangeEmail: () => changed++,
      onResend: () => resent++,
    );

    // Act
    await tester.tap(find.text('Ubah'));
    await tester.tap(find.text('Kirim ulang'));
    await tester.pump();

    // Assert
    expect(changed, 1);
    expect(resent, 1);
  });

  testWidgets('counts down until the code can be resent', (tester) async {
    // Arrange
    final until = DateTime.now().add(const Duration(seconds: 42));

    // Act
    await pumpCard(tester, resendAvailableAt: until);

    // Assert
    expect(find.textContaining('Kirim ulang dalam'), findsOneWidget);
    expect(find.text('Kirim ulang'), findsNothing);
  });

  testWidgets('shows the spam hint after 30 seconds', (tester) async {
    // Arrange
    await pumpCard(tester);
    final hint = find.text('Belum dapat? Cek folder Spam/Promosi');
    final hiddenBefore = tester
        .widget<AnimatedOpacity>(find.ancestor(of: hint, matching: find.byType(AnimatedOpacity)))
        .opacity;

    // Act
    await tester.pump(EmailCodeCard.spamHintDelay);
    await tester.pump();

    // Assert
    final shownAfter = tester
        .widget<AnimatedOpacity>(find.ancestor(of: hint, matching: find.byType(AnimatedOpacity)))
        .opacity;
    expect(hiddenBefore, 0);
    expect(shownAfter, 1);
  });

  testWidgets('a wrong code shows the caption', (tester) async {
    // Arrange
    const message = 'Kode salah. Sisa 2 kali coba.';

    // Act
    await pumpCard(tester, state: EmailCodeCardState.wrong, message: message);

    // Assert
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('an expired code offers a new one', (tester) async {
    // Arrange
    var requested = 0;
    await pumpCard(
      tester,
      state: EmailCodeCardState.expired,
      onRequestNew: () => requested++,
    );

    // Act
    await tester.tap(find.text('Kirim kode baru'));

    // Assert
    expect(find.text('Kode kedaluwarsa'), findsOneWidget);
    expect(find.byType(OtpInput), findsNothing);
    expect(requested, 1);
  });

  testWidgets('too many attempts goes back to the email screen', (tester) async {
    // Arrange
    var restarted = 0;
    await pumpCard(
      tester,
      state: EmailCodeCardState.locked,
      onRestart: () => restarted++,
    );

    // Act
    await tester.tap(find.text('Minta kode baru'));

    // Assert
    expect(
      find.text('Terlalu banyak percobaan. Minta kode baru.'),
      findsOneWidget,
    );
    expect(restarted, 1);
  });

  testWidgets('the PIN step replaces the code boxes', (tester) async {
    // Arrange
    const pinStep = Text('PIN step');

    // Act
    await pumpCard(tester, pinStep: pinStep);

    // Assert
    expect(find.text('PIN step'), findsOneWidget);
    expect(find.byType(OtpInput), findsNothing);
  });

  testWidgets('success shows the check and hides resend', (tester) async {
    // Arrange
    // (a verified code)

    // Act
    await pumpCard(tester, state: EmailCodeCardState.success);

    // Assert
    expect(find.bySemanticsLabel('Kode benar'), findsOneWidget);
    expect(find.text('Kirim ulang'), findsNothing);
  });

  testWidgets('Buka aplikasi email shows only with a callback, and calls it', (tester) async {
    // Arrange
    await pumpCard(tester);
    final withoutCallback = find.text('Buka aplikasi email').evaluate().length;
    var opened = 0;
    await pumpCard(tester, onOpenMail: () => opened++);
    // The card grows to fit the button; tap once it has. (The resend
    // countdown keeps ticking, so the tree never settles.)
    await tester.pump(AppMotion.emphasis);

    // Act
    await tester.tap(find.text('Buka aplikasi email'));
    await tester.pump();

    // Assert
    expect(withoutCallback, 0);
    expect(opened, 1);
  });
}
