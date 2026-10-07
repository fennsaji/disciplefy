import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/community/data/datasources/community_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_model.dart';
import 'package:disciplefy_bible_study/features/community/data/repositories/community_repository_impl.dart';

class _FakeDatasource implements CommunityRemoteDatasource {
  int fellowshipCalls = 0;

  @override
  Future<List<FellowshipModel>> getFellowships(String language) async {
    fellowshipCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Fellowships need an account: the server answers a guest with 403
  // ACCOUNT_REQUIRED. Every caller (Home, Topics "For you", the lesson's
  // share section) goes through the repository, so it answers for them.
  test('a guest gets no fellowships and no request is made', () async {
    final ds = _FakeDatasource();
    final repo = CommunityRepositoryImpl(datasource: ds, isGuest: () => true);

    final result = await repo.getFellowships('ml');

    expect(ds.fellowshipCalls, 0);
    result.fold(
      (failure) => fail('expected an empty list, got $failure'),
      (list) => expect(list, isEmpty),
    );
  });

  test('a full account still fetches its fellowships', () async {
    final ds = _FakeDatasource();
    final repo = CommunityRepositoryImpl(datasource: ds, isGuest: () => false);

    await repo.getFellowships('en');

    expect(ds.fellowshipCalls, 1);
  });
}
