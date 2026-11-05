import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/member.dart';

part 'transfer_candidates_usecase.g.dart';

/// Who can take over the organizer role: members with an account,
/// not guests and not the organizer making the offer.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const TransferCandidatesUseCase() {
  List<Member> call(({List<Member> members, String? myMemberId}) params) => [
    for (final m in params.members)
      if (!(m.isGuest ?? false) && m.user != null && m.id != params.myMemberId) m,
  ];
}

@Riverpod(keepAlive: true)
TransferCandidatesUseCase transferCandidatesUseCase(Ref ref) => const TransferCandidatesUseCase();
