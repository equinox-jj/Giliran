import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/error/problem_details.dart';
import '../entities/group.dart';
import '../entities/group_input.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'update_payment_info_usecase.g.dart';

/// Saves the organizer's bank account. The account number is sent as
/// digits only; a bank, number or holder the API would reject fails with a
/// [ValidationFailure] before any request.
class const UpdatePaymentInfoUseCase(final GroupRepository _repository)
    implements UseCase<GroupDetail, ({String groupId, PaymentInfoInput input})> {
  @override
  Future<Either<Failure, GroupDetail>> call(({String groupId, PaymentInfoInput input}) params) async {
    final input = params.input;
    final digits = input.accountNumber.replaceAll(RegExp(r'\D'), '');
    final bank = input.bankName.trim();
    final holder = input.accountHolder.trim();
    final errors = [
      if (bank.isEmpty)
        const FieldError(field: 'bank_name', code: 'required', message: '')
      else if (bank.length > GroupRules.maxBankNameLength)
        const FieldError(field: 'bank_name', code: 'max_length', message: ''),
      if (!GroupRules.accountNumberPattern.hasMatch(digits))
        const FieldError(field: 'account_number', code: 'invalid_format', message: ''),
      if (holder.isEmpty)
        const FieldError(field: 'account_holder', code: 'required', message: '')
      else if (holder.length > GroupRules.maxAccountHolderLength)
        const FieldError(field: 'account_holder', code: 'max_length', message: ''),
    ];
    if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    return _repository.updatePaymentInfo(
      params.groupId,
      PaymentInfoInput(bankName: bank, accountNumber: digits, accountHolder: holder),
    );
  }
}

@Riverpod(keepAlive: true)
UpdatePaymentInfoUseCase updatePaymentInfoUseCase(Ref ref) =>
    UpdatePaymentInfoUseCase(ref.watch(groupRepositoryProvider));
