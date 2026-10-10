import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/all_paths_bloc.dart';

import '../../helpers/paged_paths_repository.dart';

void main() {
  late PagedPathsRepository repository;
  late AllPathsBloc bloc;

  setUp(() {
    repository = PagedPathsRepository([
      for (var i = 1; i <= 60; i++)
        pagedPath(i, category: i > 50 ? 'Prophets' : 'Foundations'),
    ]);
    bloc = AllPathsBloc(repository: repository);
  });

  tearDown(() => bloc.close());

  Future<AllPathsState> settled() => bloc.stream
      .firstWhere((s) => s.status != AllPathsStatus.loading && !s.loadingMore);

  test('opens with the first page and every category', () async {
    bloc.add(const AllPathsOpened(language: 'en'));
    final state = await settled();
    await pumpEventQueue();

    expect(bloc.state.paths.length, AllPathsBloc.pageSize);
    expect(state.hasMore, isTrue);
    expect(bloc.state.listTotal, 60);
    expect(
        bloc.state.categories.map((c) => c.name), ['Foundations', 'Prophets']);
  });

  test('the next page is appended once, without duplicates', () async {
    bloc.add(const AllPathsOpened(language: 'en'));
    await settled();
    final gate = Completer<void>();
    repository.flatGates[AllPathsBloc.pageSize] = gate;
    bloc
      ..add(const AllPathsMoreRequested())
      ..add(const AllPathsMoreRequested());
    await pumpEventQueue();
    gate.complete();
    await settled();
    await pumpEventQueue();

    expect(repository.flatOffsets, [0, AllPathsBloc.pageSize]);
    final ids = bloc.state.paths.map((p) => p.id).toList();
    expect(ids.length, 50);
    expect(ids.toSet().length, ids.length);
  });

  test('a category pages through the category endpoint', () async {
    bloc.add(const AllPathsOpened(language: 'en', category: 'Foundations'));
    await settled();
    bloc.add(const AllPathsMoreRequested());
    await settled();

    expect(repository.categoryOffsets, [0, AllPathsBloc.pageSize]);
    expect(repository.flatOffsets, isEmpty);
    expect(bloc.state.paths.every((p) => p.category == 'Foundations'), isTrue);
  });

  test('the newest search wins over a slower older one', () async {
    repository.searchDelays['path 1'] = const Duration(milliseconds: 80);
    bloc.add(const AllPathsOpened(language: 'en'));
    await settled();

    bloc.add(const AllPathsSearchChanged('path 1'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    bloc.add(const AllPathsSearchChanged('path 55'));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(bloc.state.query, 'path 55');
    expect(bloc.state.paths.map((p) => p.title), ['Path 55']);
  });

  test('a language change drops the old list and reloads', () async {
    bloc.add(const AllPathsOpened(language: 'en'));
    await settled();

    final states = <AllPathsState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const AllPathsLanguageChanged('hi'));
    await settled();
    await pumpEventQueue();
    await sub.cancel();

    expect(states.first.paths, isEmpty);
    expect(repository.flatLanguages.last, 'hi');
    expect(repository.summaryRequests.last, 'hi');
    expect(bloc.state.language, 'hi');
    expect(bloc.state.paths, isNotEmpty);
  });

  test('a failed refresh keeps the list on screen', () async {
    bloc.add(const AllPathsOpened(language: 'en'));
    await settled();
    repository.failFlatAt = 0;

    final done = Completer<void>();
    bloc.add(AllPathsRefreshed(done: done));
    await done.future;

    expect(bloc.state.status, AllPathsStatus.loaded);
    expect(bloc.state.paths.length, AllPathsBloc.pageSize);
  });

  test('a failed first page is an error, never a lasting load', () async {
    repository.failFlatAt = 0;
    bloc.add(const AllPathsOpened(language: 'en'));
    final state = await settled();
    expect(state.status, AllPathsStatus.error);
  });

  test('categories summary type carries name and count', () {
    expect(
      const LearningPathCategorySummary(name: 'A', totalPaths: 2),
      const LearningPathCategorySummary(name: 'A', totalPaths: 2),
    );
  });
}
