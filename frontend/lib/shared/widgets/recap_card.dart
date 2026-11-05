import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_doodles.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/date_formatter.dart';
import 'doodle.dart';
import 'giliran_ring.dart';

/// The WhatsApp recap card (Tikar §9.11, feature 33): the image an organizer
/// posts to the group chat, built for people who never open the app.
///
/// Always drawn with the light theme on the group's light [tone], so every
/// recipient sees the same image. Lists at most [maxNames] unpaid names,
/// then "+{n} lainnya"; it only takes names, never phone numbers. Laid out
/// for the [RecapExportFrame] (360 × 450, exported at 1080 × 1350) and
/// scaled down as a preview.
class const RecapCard({
  super.key,
  required final String groupName,
  required final int periodNo,
  required final int totalPeriods,
  required final int paidCount,
  required final int totalCount,
  required final int collectedAmount,
  required final int expectedAmount,

  /// Names exactly as shown in the group, by slot number.
  required final List<String> unpaidNames,

  /// Jakarta business dates.
  final DateTime? dueDate,
  final DateTime? drawDate,

  /// "BCA 1234567890 a.n. Rina", or null when the group has no account.
  final String? account,
  required final GroupTone tone,

  /// "Now" for the date format (this year or not).
  final DateTime? now,
}) extends StatelessWidget {
  static const maxNames = 8;

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.light(),
    child: _RecapFace(card: this),
  );
}

/// The card's content under the forced light theme.
class const _RecapFace({required final RecapCard card}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    const t = AppTextStyles.phone();
    final names = card.unpaidNames;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: card.tone.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: DefaultTextStyle(
          style: t.body.copyWith(color: c.textPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                card.groupName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.micro.copyWith(color: c.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: AppSpace.s1),
              Text(l10n.recapPeriod(card.periodNo, card.totalPeriods), style: t.titleLg),
              const SizedBox(height: AppSpace.s3),
              _Progress(card: card),
              const SizedBox(height: AppSpace.s3),
              // The names take what is left of the fixed 4:5 frame.
              Expanded(
                child: names.isEmpty
                    ? const Align(alignment: Alignment.topLeft, child: _AllPaid())
                    : _Unpaid(names: names),
              ),
              const SizedBox(height: AppSpace.s2),
              _Facts(card: card),
              const SizedBox(height: AppSpace.s2),
              Divider(color: c.textPrimary.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: AppSpace.s2),
              Row(
                children: [
                  Text(l10n.recapFooter, style: t.caption.copyWith(color: c.textSecondary)),
                  const SizedBox(width: AppSpace.s1),
                  Doodle(AppDoodles.kaleng, size: 16, color: c.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ring and the collected amount.
class const _Progress({required final RecapCard card}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const t = AppTextStyles.phone();
    return Row(
      children: [
        GiliranRing(
          value: card.paidCount,
          total: card.totalCount,
          size: GiliranRingSize.s96,
          color: card.tone.accent,
          semanticsLabel: context.l10n.recapRingSemantics(card.paidCount, card.totalCount),
        ),
        const SizedBox(width: AppSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Rupiah.format(card.collectedAmount), style: t.amountXl),
              ),
              Text(
                context.l10n.recapOfExpected(Rupiah.format(card.expectedAmount)),
                style: t.body.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Belum bayar:" and up to [RecapCard.maxNames] names, then "+n lainnya".
/// Long names shrink to fit the space left instead of being cut off, so
/// nobody is missing from the image.
class const _Unpaid({required final List<String> names}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const t = AppTextStyles.phone();
    final shown = names.take(RecapCard.maxNames).map((n) => '• $n').join('  ');
    final rest = names.length - RecapCard.maxNames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.recapUnpaidTitle, style: t.title),
        const SizedBox(height: AppSpace.s1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Text(rest > 0 ? '$shown  ${l10n.recapMore(rest)}' : shown, style: t.bodyLg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class const _AllPaid() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const t = AppTextStyles.phone();
    return Row(
      children: [
        Doodle(AppDoodles.gelas, size: 56, color: c.paid.fg),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Text(context.l10n.recapAllPaid, style: t.title.copyWith(color: c.paid.fg)),
        ),
      ],
    );
  }
}

/// Due date, draw date and where to transfer.
class const _Facts({required final RecapCard card}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = card.dueDate;
    final draw = card.drawDate;
    final account = card.account;
    return Column(
      children: [
        if (due != null)
          _Fact(
            label: l10n.recapDueDate,
            value: AppDate.short(due, now: card.now),
          ),
        if (draw != null)
          _Fact(
            label: l10n.recapDrawDate,
            value: AppDate.short(draw, now: card.now),
          ),
        if (account != null) _Fact(label: l10n.recapTransfer, value: account),
      ],
    );
  }
}

class const _Fact({required final String label, required final String value}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const t = AppTextStyles.phone();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: t.body.copyWith(color: c.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 4:5 frame the recap is exported in: 360 × 450 logical px, rendered
/// at pixel ratio 3 for a 1080 × 1350 PNG. The preview shows the same frame scaled
/// to fit as the preview, so what the organizer sees is what gets shared.
class const RecapExportFrame({super.key, required final Widget card}) extends StatelessWidget {
  static const size = Size(360, 450);
  static const pixelRatio = 3.0;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(size: size, child: card);
}
