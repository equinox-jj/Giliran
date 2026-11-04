import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/invite_preview.dart';
import '../../data/repositories/member_repository_impl.dart';
import '../repositories/member_repository.dart';

part 'get_invite_preview_usecase.g.dart';

/// The group behind an invite code, for Join preview (S25).
class const GetInvitePreviewUseCase(final MemberRepository _repository) implements UseCase<InvitePreview, String> {
  @override
  Future<Either<Failure, InvitePreview>> call(String params) =>
      _repository.getInvitePreview(params.trim().toUpperCase());
}

@Riverpod(keepAlive: true)
GetInvitePreviewUseCase getInvitePreviewUseCase(Ref ref) =>
    GetInvitePreviewUseCase(ref.watch(memberRepositoryProvider));
