import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/data/datasources/community_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_model.dart';
import 'package:disciplefy_bible_study/features/community/data/repositories/community_repository_impl.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_meeting_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/home/presentation/pages/home_screen.dart';

class _FakeDatasource implements CommunityRemoteDatasource {
  int fellowshipCalls = 0;
  Completer<List<FellowshipModel>> fellowships = Completer();

  @override
  Future<List<FellowshipModel>> getFellowships(String language) {
    fellowshipCalls++;
    return fellowships.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MeetingsRepo implements CommunityRepository {
  final Map<String, Completer<Either<Failure, List<FellowshipMeetingEntity>>>>
      pending = {};

  @override
  Future<Either<Failure, List<FellowshipMeetingEntity>>> getMeetings(
      String fellowshipId) {
    final c = Completer<Either<Failure, List<FellowshipMeetingEntity>>>();
    pending[fellowshipId] = c;
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FellowshipModel _model(String id) => FellowshipModel(
      id: id,
      name: 'F$id',
      memberCount: 1,
      userRole: 'member',
      joinedAt: '2026-01-01T00:00:00Z',
      createdAt: '2026-01-01T00:00:00Z',
    );

FellowshipEntity _entity(String id) => FellowshipEntity(
      id: id,
      name: 'F$id',
      memberCount: 1,
      userRole: 'member',
      joinedAt: '2026-01-01T00:00:00Z',
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  test('concurrent fellowship list requests share one call', () async {
    final ds = _FakeDatasource();
    final repo = CommunityRepositoryImpl(datasource: ds);

    final a = repo.getFellowships('en');
    final b = repo.getFellowships('en');
    expect(ds.fellowshipCalls, 1);

    ds.fellowships.complete([_model('1')]);
    final results = await Future.wait([a, b]);
    for (final r in results) {
      expect(r.getOrElse(() => []).single.id, '1');
    }

    // Once settled, a later call goes to the network again (no caching).
    ds.fellowships = Completer()..complete([]);
    await repo.getFellowships('en');
    expect(ds.fellowshipCalls, 2);
  });

  test('meetings for all fellowships are requested in parallel, in order',
      () async {
    final repo = _MeetingsRepo();
    final future = fetchMeetingsInParallel(repo, [_entity('a'), _entity('b')]);

    // Both requests started before either completed.
    expect(repo.pending.keys, ['a', 'b']);
    repo.pending['b']!.complete(const Right([]));
    repo.pending['a']!.complete(const Left(ServerFailure(message: 'x')));

    final results = await future;
    expect(results[0].isLeft(), isTrue);
    expect(results[1].isRight(), isTrue);
  });
}
