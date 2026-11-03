import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/group_list_filter.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/group/domain/entities/group_input.dart';
import 'package:giliran/features/group/domain/entities/group_summary.dart';
import 'package:giliran/features/group/domain/repositories/group_repository.dart';

/// Records each call and answers with the configured results. Watch streams
/// start with the current [groups] / [group] and re-emit on [emitGroups] /
/// [emitGroup].
class FakeGroupRepository() implements GroupRepository {
  final calls = <String>[];
  final refreshedFilters = <GroupListFilter>[];
  final watchedFilters = <GroupListFilter>[];
  CreateGroupInput? lastCreate;
  UpdateGroupInput? lastUpdate;
  PaymentInfoInput? lastPaymentInfo;
  String? lastQrisPath;

  List<GroupSummary> groups = [];
  GroupDetail? group = const GroupDetail(id: 'g1', name: 'Arisan RT 05');

  Either<Failure, Unit> refreshResult = const Right(unit);
  Either<Failure, GroupDetail>? groupResult;
  Either<Failure, Unit> deleteQrisResult = const Right(unit);

  final _groups = StreamController<List<GroupSummary>>.broadcast();
  final _group = StreamController<GroupDetail?>.broadcast();

  void emitGroups(List<GroupSummary> value) {
    groups = value;
    _groups.add(value);
  }

  void emitGroup(GroupDetail? value) {
    group = value;
    _group.add(value);
  }

  Future<Either<Failure, GroupDetail>> _groupAnswer(String name) async {
    calls.add(name);
    return groupResult ?? Right(group ?? const GroupDetail(id: 'g1'));
  }

  @override
  Stream<Either<Failure, List<GroupSummary>>> watchMyGroups(GroupListFilter filter) async* {
    watchedFilters.add(filter);
    yield Right(groups);
    yield* _groups.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, Unit>> refreshMyGroups(GroupListFilter filter) async {
    calls.add('refreshMyGroups');
    refreshedFilters.add(filter);
    return refreshResult;
  }

  @override
  Stream<Either<Failure, GroupDetail?>> watchGroup(String id) async* {
    yield Right(group);
    yield* _group.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, GroupDetail>> refreshGroup(String id) => _groupAnswer('refreshGroup');

  @override
  Future<Either<Failure, GroupDetail>> createGroup(CreateGroupInput input) {
    lastCreate = input;
    return _groupAnswer('createGroup');
  }

  @override
  Future<Either<Failure, GroupDetail>> updateGroup(String id, UpdateGroupInput input) {
    lastUpdate = input;
    return _groupAnswer('updateGroup');
  }

  @override
  Future<Either<Failure, GroupDetail>> closeGroup(String id) => _groupAnswer('closeGroup');

  @override
  Future<Either<Failure, GroupDetail>> updatePaymentInfo(String id, PaymentInfoInput input) {
    lastPaymentInfo = input;
    return _groupAnswer('updatePaymentInfo');
  }

  @override
  Future<Either<Failure, GroupDetail>> uploadQris(String id, String path) {
    lastQrisPath = path;
    return _groupAnswer('uploadQris');
  }

  @override
  Future<Either<Failure, Unit>> deleteQris(String id) async {
    calls.add('deleteQris');
    return deleteQrisResult;
  }
}
