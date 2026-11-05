import '../../../member/domain/entities/member.dart';

/// A drawn period on the summary's "Pemenang per periode" list.
class const CycleWinner({
  required final String periodId,
  required final int periodNo,
  final MemberRef? winner,
  final DateTime? drawnAt,
});

/// The whole cycle of a completed or closed group.
class const CycleSummary({
  required final int periodCount,
  required final int winnerCount,

  /// Rupiah collected over every period.
  required final int totalCollected,

  /// Share of dues paid over the periods with a payment summary; null
  /// when none is cached.
  required final int? paidPercent,
  required final int memberCount,

  /// Closed by the organizer before every period was drawn.
  required final bool closedEarly,
  final DateTime? endedAt,
  final List<CycleWinner> winners = const [],

  /// Periods a closed group never drew ("Tidak dikocok").
  final List<int> undrawnPeriodNos = const [],
});
