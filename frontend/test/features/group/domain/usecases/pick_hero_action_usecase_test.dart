import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/group/domain/usecases/pick_hero_action_usecase.dart';

HeroInput _input({
  GroupStatus status = GroupStatus.active,
  MemberRole role = MemberRole.member,
  PaymentStatus? payment = PaymentStatus.paid,
  int pending = 0,
  bool drawDateReached = false,
  bool drawn = false,
  bool payoutRecorded = false,
}) => (
  status: status,
  role: role,
  myPaymentStatus: payment,
  pendingCount: pending,
  drawDateReached: drawDateReached,
  drawn: drawn,
  payoutRecorded: payoutRecorded,
);

void main() {
  final rows = <String, (HeroInput, HeroAction)>{
    'member, own payment unpaid → upload': (_input(payment: PaymentStatus.unpaid), HeroAction.uploadProof),
    'member, own payment rejected → upload': (_input(payment: PaymentStatus.rejected), HeroAction.uploadProof),
    'member, own payment pending → view my proof': (
      _input(payment: PaymentStatus.pendingReview),
      HeroAction.viewMyProof,
    ),
    'member, paid, not drawn → wait for the draw': (_input(), HeroAction.waitForDraw),
    'organizer, pending proofs → review': (_input(role: MemberRole.organizer, pending: 2), HeroAction.reviewProofs),
    'organizer, draw date reached → draw now': (
      _input(role: MemberRole.organizer, drawDateReached: true),
      HeroAction.drawNow,
    ),
    'organizer, drawn, payout not recorded → record payout': (
      _input(role: MemberRole.organizer, drawn: true),
      HeroAction.recordPayout,
    ),
    'anyone, payout recorded → Bukti Kocok': (_input(payoutRecorded: true), HeroAction.viewBuktiKocok),
    'draft, organizer → continue setup': (
      _input(status: GroupStatus.draft, role: MemberRole.organizer),
      HeroAction.continueSetup,
    ),
    'draft, member → nothing': (_input(status: GroupStatus.draft), HeroAction.none),
    'co-organizer acts like the organizer': (
      _input(role: MemberRole.coOrganizer, pending: 1),
      HeroAction.reviewProofs,
    ),
    'organizer with nothing to manage falls back to own payment': (
      _input(role: MemberRole.organizer, payment: PaymentStatus.unpaid),
      HeroAction.uploadProof,
    ),
    'pending proofs come before the draw for the organizer': (
      _input(role: MemberRole.organizer, pending: 1, drawDateReached: true),
      HeroAction.reviewProofs,
    ),
    'member, paid and drawn → nothing': (_input(drawn: true), HeroAction.none),
    'completed group → the summary': (_input(status: GroupStatus.completed), HeroAction.viewSummary),
    'closed group → the summary, for members too': (
      _input(status: GroupStatus.closed, role: MemberRole.member),
      HeroAction.viewSummary,
    ),
  };
  for (final MapEntry(key: label, value: (input, expected)) in rows.entries) {
    test(label, () {
      // Act
      final action = const PickHeroActionUseCase()(input);

      // Assert
      expect(action, expected);
    });
  }
}
