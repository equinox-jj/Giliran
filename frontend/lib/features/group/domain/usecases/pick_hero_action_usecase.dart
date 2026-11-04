import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/member_role.dart';
import '../../../../core/utils/enums/payment_status.dart';

part 'pick_hero_action_usecase.g.dart';

/// The Current Period Hero's primary action (Tikar §9.4).
enum HeroAction() {
  uploadProof,
  viewMyProof,
  waitForDraw,
  reviewProofs,
  drawNow,
  recordPayout,
  viewBuktiKocok,
  continueSetup,

  /// The group is completed or closed: open its summary (S24).
  viewSummary,
  none,
}

/// What [PickHeroActionUseCase] decides from. [drawn] and [payoutRecorded]
/// come from the current period once periods are loaded (Phase 4–5).
typedef HeroInput = ({
  GroupStatus? status,
  MemberRole? role,
  PaymentStatus? myPaymentStatus,
  int pendingCount,
  bool drawDateReached,
  bool drawn,
  bool payoutRecorded,
});

/// Picks the hero action by the §9.4 table. A draft group asks managers to
/// continue setup; a completed or closed one opens its summary for
/// everyone. Once the payout is recorded anyone sees the Bukti Kocok.
/// Managers then get, in order: record payout (drawn), review proofs,
/// draw now (draw date reached). Otherwise my own payment decides: upload
/// (unpaid or rejected), view my proof (pending), or wait for the draw
/// (paid, not drawn).
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const PickHeroActionUseCase() {
  HeroAction call(HeroInput input) {
    final manager = input.role == MemberRole.organizer || input.role == MemberRole.coOrganizer;
    if (input.status == GroupStatus.draft) return manager ? HeroAction.continueSetup : HeroAction.none;
    if (input.status == GroupStatus.completed || input.status == GroupStatus.closed) return HeroAction.viewSummary;
    if (input.status != GroupStatus.active) return HeroAction.none;
    if (input.payoutRecorded) return HeroAction.viewBuktiKocok;
    if (manager) {
      if (input.drawn) return HeroAction.recordPayout;
      if (input.pendingCount > 0) return HeroAction.reviewProofs;
      if (input.drawDateReached) return HeroAction.drawNow;
    }
    return switch (input.myPaymentStatus) {
      PaymentStatus.unpaid || PaymentStatus.rejected => HeroAction.uploadProof,
      PaymentStatus.pendingReview => HeroAction.viewMyProof,
      PaymentStatus.paid when !input.drawn => HeroAction.waitForDraw,
      _ => HeroAction.none,
    };
  }
}

@Riverpod(keepAlive: true)
PickHeroActionUseCase pickHeroActionUseCase(Ref ref) => const PickHeroActionUseCase();
