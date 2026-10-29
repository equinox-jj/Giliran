import 'package:material_ui/material_ui.dart';

import '../utils/enums/payment_status.dart';
import 'app_palette.dart';

/// A status color pair: foreground (icon, label) on background (chip fill).
@immutable
class StatusColors {
  const StatusColors({required this.fg, required this.bg});

  final Color fg;
  final Color bg;

  static StatusColors lerp(StatusColors a, StatusColors b, double t) =>
      StatusColors(
        fg: Color.lerp(a.fg, b.fg, t)!,
        bg: Color.lerp(a.bg, b.bg, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is StatusColors && other.fg == fg && other.bg == bg;

  @override
  int get hashCode => Object.hash(fg, bg);
}

/// One group tone: the card / hero fill and its ring / accent color.
@immutable
class GroupTone {
  const GroupTone({required this.surface, required this.accent});

  final Color surface;
  final Color accent;

  static GroupTone lerp(GroupTone a, GroupTone b, double t) => GroupTone(
    surface: Color.lerp(a.surface, b.surface, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is GroupTone && other.surface == surface && other.accent == accent;

  @override
  int get hashCode => Object.hash(surface, accent);
}

/// Semantic colors of the Tikar design system, light and dark.
@immutable
class GiliranColors extends ThemeExtension<GiliranColors> {
  const GiliranColors({
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.subtle,
    required this.hero,
    required this.inverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnInverse,
    required this.link,
    required this.hairline,
    required this.borderStrong,
    required this.turn,
    required this.focus,
    required this.scrim,
    required this.dangerFill,
    required this.onDanger,
    required this.ink,
    required this.ticketBody,
    required this.ticketStub,
    required this.viewerBg,
    required this.paid,
    required this.pending,
    required this.unpaid,
    required this.rejected,
    required this.info,
    required this.won,
    required this.tones,
  });

  /// Backgrounds: page, cards and rows, sheets and nav, fields and skeletons,
  /// the home hero, and ink (primary button, "you" row, selected chip).
  final Color page, surface, surfaceRaised, subtle, hero, inverse;
  final Color textPrimary, textSecondary, textTertiary, textOnInverse, link;
  final Color hairline, borderStrong, turn, focus, scrim;

  /// Destructive button fill and its label.
  final Color dangerFill, onDanger;

  /// Fixed in both themes: ink content on kunyit, the Bukti Kocok ticket and
  /// the image viewer backdrop, because they are exported as images.
  final Color ink, ticketBody, ticketStub, viewerBg;

  final StatusColors paid, pending, unpaid, rejected, info, won;

  /// Order: pandan, telang, jambu, kunyit, kopi.
  final List<GroupTone> tones;

  /// Light tones regardless of theme, for exported images (WhatsApp recap).
  static const List<GroupTone> exportTones = _lightTones;

  StatusColors forPayment(PaymentStatus status, {bool overdue = false}) {
    if (overdue &&
        (status == PaymentStatus.unpaid || status == PaymentStatus.rejected)) {
      return rejected;
    }
    return switch (status) {
      PaymentStatus.paid => paid,
      PaymentStatus.pendingReview => pending,
      PaymentStatus.unpaid => unpaid,
      PaymentStatus.rejected => rejected,
    };
  }

  /// Stable tone index per group, derived from its id (FNV-1a 32-bit).
  static int toneIndexFor(String groupId, {int count = 5}) {
    var hash = 0x811C9DC5;
    for (final unit in groupId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % count;
  }

  GroupTone toneFor(String groupId) =>
      tones[toneIndexFor(groupId, count: tones.length)];

  static const _lightTones = [
    GroupTone(surface: AppPalette.pandan200, accent: AppPalette.pandan700),
    GroupTone(surface: AppPalette.telang200, accent: AppPalette.telang700),
    GroupTone(surface: AppPalette.jambu200, accent: AppPalette.jambu700),
    GroupTone(surface: AppPalette.kunyit200, accent: AppPalette.kunyit800),
    GroupTone(surface: AppPalette.kopi200, accent: AppPalette.kopi700),
  ];

  static const light = GiliranColors(
    page: AppPalette.kopi50,
    surface: AppPalette.white,
    surfaceRaised: AppPalette.white,
    subtle: AppPalette.kopi100,
    hero: AppPalette.pandan200,
    inverse: AppPalette.kopi900,
    textPrimary: AppPalette.kopi900,
    textSecondary: AppPalette.kopi700,
    textTertiary: AppPalette.kopi600,
    textOnInverse: AppPalette.kopi50,
    link: AppPalette.pandan700,
    hairline: AppPalette.kopi200,
    borderStrong: AppPalette.kopi500,
    turn: AppPalette.kunyit400,
    focus: AppPalette.telang700,
    scrim: AppPalette.scrimLight,
    dangerFill: AppPalette.bata600,
    onDanger: AppPalette.white,
    ink: AppPalette.kopi900,
    ticketBody: AppPalette.kunyit400,
    ticketStub: AppPalette.kopi50,
    viewerBg: AppPalette.kopi950,
    paid: StatusColors(fg: AppPalette.pandan700, bg: AppPalette.pandan50),
    pending: StatusColors(fg: AppPalette.kunyit800, bg: AppPalette.kunyit50),
    unpaid: StatusColors(fg: AppPalette.kopi700, bg: AppPalette.kopi100),
    rejected: StatusColors(fg: AppPalette.bata700, bg: AppPalette.bata50),
    info: StatusColors(fg: AppPalette.telang700, bg: AppPalette.telang50),
    won: StatusColors(fg: AppPalette.kopi900, bg: AppPalette.kunyit400),
    tones: _lightTones,
  );

  static const dark = GiliranColors(
    page: AppPalette.kopi950,
    surface: AppPalette.kopi850,
    surfaceRaised: AppPalette.kopi800,
    subtle: AppPalette.darkSubtle,
    hero: AppPalette.pandan800,
    inverse: AppPalette.cream,
    textPrimary: AppPalette.cream,
    textSecondary: AppPalette.creamMuted,
    textTertiary: AppPalette.creamFaint,
    textOnInverse: AppPalette.kopi900,
    link: AppPalette.pandan300,
    hairline: AppPalette.darkHairline,
    borderStrong: AppPalette.darkBorderStrong,
    turn: AppPalette.kunyit400,
    focus: AppPalette.telang300,
    scrim: AppPalette.scrimDark,
    dangerFill: AppPalette.bata300,
    onDanger: AppPalette.kopi900,
    ink: AppPalette.kopi900,
    ticketBody: AppPalette.kunyit400,
    ticketStub: AppPalette.kopi50,
    viewerBg: AppPalette.kopi950,
    paid: StatusColors(fg: AppPalette.pandan300, bg: AppPalette.pandan950),
    pending: StatusColors(fg: AppPalette.kunyit300, bg: AppPalette.kunyit950),
    unpaid: StatusColors(fg: AppPalette.creamMuted, bg: AppPalette.darkSubtle),
    rejected: StatusColors(fg: AppPalette.bata300, bg: AppPalette.bata950),
    info: StatusColors(fg: AppPalette.telang300, bg: AppPalette.telang950),
    won: StatusColors(fg: AppPalette.kopi900, bg: AppPalette.kunyit400),
    tones: [
      GroupTone(surface: AppPalette.pandan800, accent: AppPalette.pandan300),
      GroupTone(surface: AppPalette.telang800, accent: AppPalette.telang300),
      GroupTone(surface: AppPalette.jambu800, accent: AppPalette.jambu200),
      GroupTone(surface: AppPalette.kunyit950, accent: AppPalette.kunyit300),
      GroupTone(surface: AppPalette.kopi800, accent: AppPalette.kopi300),
    ],
  );

  @override
  GiliranColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceRaised,
    Color? subtle,
    Color? hero,
    Color? inverse,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnInverse,
    Color? link,
    Color? hairline,
    Color? borderStrong,
    Color? turn,
    Color? focus,
    Color? scrim,
    Color? dangerFill,
    Color? onDanger,
    Color? ink,
    Color? ticketBody,
    Color? ticketStub,
    Color? viewerBg,
    StatusColors? paid,
    StatusColors? pending,
    StatusColors? unpaid,
    StatusColors? rejected,
    StatusColors? info,
    StatusColors? won,
    List<GroupTone>? tones,
  }) => GiliranColors(
    page: page ?? this.page,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    subtle: subtle ?? this.subtle,
    hero: hero ?? this.hero,
    inverse: inverse ?? this.inverse,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    textOnInverse: textOnInverse ?? this.textOnInverse,
    link: link ?? this.link,
    hairline: hairline ?? this.hairline,
    borderStrong: borderStrong ?? this.borderStrong,
    turn: turn ?? this.turn,
    focus: focus ?? this.focus,
    scrim: scrim ?? this.scrim,
    dangerFill: dangerFill ?? this.dangerFill,
    onDanger: onDanger ?? this.onDanger,
    ink: ink ?? this.ink,
    ticketBody: ticketBody ?? this.ticketBody,
    ticketStub: ticketStub ?? this.ticketStub,
    viewerBg: viewerBg ?? this.viewerBg,
    paid: paid ?? this.paid,
    pending: pending ?? this.pending,
    unpaid: unpaid ?? this.unpaid,
    rejected: rejected ?? this.rejected,
    info: info ?? this.info,
    won: won ?? this.won,
    tones: tones ?? this.tones,
  );

  @override
  GiliranColors lerp(GiliranColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GiliranColors(
      page: c(page, other.page),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      subtle: c(subtle, other.subtle),
      hero: c(hero, other.hero),
      inverse: c(inverse, other.inverse),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textOnInverse: c(textOnInverse, other.textOnInverse),
      link: c(link, other.link),
      hairline: c(hairline, other.hairline),
      borderStrong: c(borderStrong, other.borderStrong),
      turn: c(turn, other.turn),
      focus: c(focus, other.focus),
      scrim: c(scrim, other.scrim),
      dangerFill: c(dangerFill, other.dangerFill),
      onDanger: c(onDanger, other.onDanger),
      ink: c(ink, other.ink),
      ticketBody: c(ticketBody, other.ticketBody),
      ticketStub: c(ticketStub, other.ticketStub),
      viewerBg: c(viewerBg, other.viewerBg),
      paid: StatusColors.lerp(paid, other.paid, t),
      pending: StatusColors.lerp(pending, other.pending, t),
      unpaid: StatusColors.lerp(unpaid, other.unpaid, t),
      rejected: StatusColors.lerp(rejected, other.rejected, t),
      info: StatusColors.lerp(info, other.info, t),
      won: StatusColors.lerp(won, other.won, t),
      tones: [
        for (var i = 0; i < tones.length; i++)
          GroupTone.lerp(tones[i], other.tones[i], t),
      ],
    );
  }
}

extension GiliranColorsX on BuildContext {
  GiliranColors get colors => Theme.of(this).extension<GiliranColors>()!;
}
