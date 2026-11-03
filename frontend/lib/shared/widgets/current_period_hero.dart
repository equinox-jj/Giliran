import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_doodles.dart';
import '../../core/themes/themes.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'doodle.dart';
import 'giliran_ring.dart';

/// The hero's primary action: an ink button, or a secondary one with no
/// ink (Tikar §9.4).
@immutable
class const CurrentPeriodHeroAction({
  required final String label,
  required final VoidCallback onPressed,
  final bool secondary = false,
});

/// The Current Period Hero (Tikar §9.4) in the group tone: name and period
/// label, the payment ring, the collected amount, the due and draw line, and
/// one action chosen by role and state. Draft groups reuse it as the setup
/// card with the fill ring.
class const CurrentPeriodHero({
  super.key,
  required final String title,
  required final String subtitle,
  required final int ringValue,
  required final int ringTotal,
  final int ringPending = 0,
  required final String ringSemantics,
  final int? amount,

  /// "dari Rp2.000.000" under [amount].
  final String? amountCaption,

  /// "Jatuh tempo Sab, 25 Okt · Kocok Min, 26 Okt".
  final String? infoLine,
  final CurrentPeriodHeroAction? action,

  /// Text shown instead of a button ("Tinggal tunggu kocokan").
  final String? note,
  final GroupTone? tone,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final large = !context.isCompact;
    return HeroPanel(
      color: tone?.surface ?? c.hero,
      decoration: const Doodle(AppDoodles.kaleng),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLg.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(subtitle, style: t.body.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              GiliranRing(
                value: ringValue,
                total: ringTotal,
                pending: ringPending,
                size: large ? GiliranRingSize.s120 : GiliranRingSize.s96,
                color: tone?.accent,
                semanticsLabel: ringSemantics,
              ),
            ],
          ),
          if (amount != null) ...[
            const SizedBox(height: AppSpace.s3),
            Text.rich(Rupiah.span(amount!, t.amountXl.copyWith(color: c.textPrimary))),
            if (amountCaption != null) Text(amountCaption!, style: t.body.copyWith(color: c.textSecondary)),
          ],
          if (infoLine != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(infoLine!, style: t.body.copyWith(color: c.textSecondary)),
          ],
          if (action != null || note != null) const SizedBox(height: AppSpace.s4),
          if (action case final a?)
            a.secondary
                ? AppButton.secondary(label: a.label, onPressed: a.onPressed)
                : AppButton(label: a.label, onPressed: a.onPressed)
          else if (note != null)
            Text(note!, style: t.label.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
