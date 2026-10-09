import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';

import '../../helpers/paged_paths_repository.dart';

void main() {
  late PagedPathsRepository repository;
  late LearningPathsBloc bloc;

  LearningPathsBloc build() => LearningPathsBloc(
        repository: repository,
        resetLearningProgress: ResetLearningProgress(repository),
      );

  Future<LearningPathsState> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return bloc.state;
  }

  setUp(() {
    repository = PagedPathsRepository([
      for (var i = 1; i <= 120; i++) pagedPath(i),
    ]);
    bloc = build();
  });

  tearDown(() => bloc.close());

  test('the flat list loads every page until the server has no more', () async {
    bloc.add(const LoadFlatLearningPaths());
    final state = await settle();

    expect(state, isA<LearningPathsLoaded>());
    final paths = (state as LearningPathsLoaded).searchResults!;
    expect(paths, hasLength(120));
    expect(paths.map((p) => p.id).toSet(), hasLength(120));
    expect(paths.last.title, 'Path 120');
    expect(repository.flatOffsets, [0, 50, 100]);
  });

  test('a failed later page is an error, not a short list', () async {
    repository.failFlatAt = 50;
    bloc.add(const LoadFlatLearningPaths());
    expect(await settle(), isA<LearningPathsError>());
  });

  test('a search returns matches from every page', () async {
    bloc.add(const LoadFlatLearningPaths());
    await settle();
    bloc.add(const SearchLearningPaths(query: 'path'));
    final state = await settle() as LearningPathsLoaded;
    expect(state.searchQuery, 'path');
    expect(state.searchResults, hasLength(120));
    expect(state.searchResults!.any((p) => p.title == 'Path 115'), isTrue);
  });

  test('an older, slower search never replaces the newer one', () async {
    bloc.add(const LoadFlatLearningPaths());
    await settle();
    repository.searchDelays['path 1'] = const Duration(milliseconds: 30);
    bloc
      ..add(const SearchLearningPaths(query: 'path 1'))
      ..add(const SearchLearningPaths(query: 'path 11'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final state = bloc.state as LearningPathsLoaded;
    expect(state.searchQuery, 'path 11');
    // Path 11 and Path 110–119.
    expect(state.searchResults, hasLength(11));
  });

  test('a category page that repeats a listed path does not list it twice',
      () async {
    bloc.add(const LoadLearningPaths());
    await settle();
    // Path 3 moved down meanwhile (finished): the next page starts with it.
    final category = (bloc.state as LearningPathsLoaded).categories.single;
    expect(category.paths, hasLength(3));
    repository.paths.insert(3, repository.paths[2]);
    bloc.add(const LoadMorePathsForCategory(category: 'Foundations'));
    final state = await settle() as LearningPathsLoaded;
    final ids = state.categories.single.paths.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, ['p1', 'p2', 'p3', 'p4', 'p5']);
  });
}
