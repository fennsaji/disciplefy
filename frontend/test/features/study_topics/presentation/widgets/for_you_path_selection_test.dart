import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/for_you_learning_paths_section.dart';
import 'package:flutter_test/flutter_test.dart';

LearningPath _path(
  String id, {
  bool featured = false,
  int progress = 0,
  bool enrolled = false,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: id,
      description: '',
      iconName: 'star',
      color: '#000000',
      totalXp: 100,
      estimatedDays: 7,
      discipleLevel: 'seeker',
      isFeatured: featured,
      topicsCount: 8,
      isEnrolled: enrolled || progress > 0,
      progressPercentage: progress,
    );

LearningPathsLoaded _state(
  List<LearningPath> paths, {
  List<LearningPath> personalized = const [],
}) =>
    LearningPathsLoaded(
      categories: [
        LearningPathCategory(
          name: 'Foundations',
          paths: paths,
          totalInCategory: paths.length,
        ),
      ],
      enrolledPaths: paths.where((p) => p.isEnrolled).toList(),
      personalizedPaths: personalized,
    );

void main() {
  test('a path the fellowship completed is never recommended', () {
    // Group study leaves personal progress at 0, so this path looks untouched.
    final groupDone = _path('group-done', featured: true);
    final fresh = _path('fresh', featured: true);

    final result = buildForYouPaths(
      state: _state([groupDone, fresh]),
      fellowshipCompletedPathIds: {'group-done'},
      fellowshipPath: null,
      minCount: 3,
    );

    expect(result.map((p) => p.id), ['fresh']);
  });

  test('fellowship completion also removes it from personalized results', () {
    final groupDone = _path('group-done');
    final fresh = _path('fresh');

    final result = buildForYouPaths(
      state: _state([groupDone, fresh], personalized: [groupDone, fresh]),
      fellowshipCompletedPathIds: {'group-done'},
      fellowshipPath: null,
      minCount: 3,
    );

    expect(result.map((p) => p.id), ['fresh']);
  });

  test('the fellowship active path is not prepended once the group finishes it',
      () {
    final active = _path('active');

    final result = buildForYouPaths(
      state: _state([active, _path('fresh', featured: true)]),
      fellowshipCompletedPathIds: {'active'},
      fellowshipPath: active,
      minCount: 3,
    );

    expect(result.map((p) => p.id), isNot(contains('active')));
  });

  test('a path the user completed personally is still excluded', () {
    final mine = _path('mine', featured: true, progress: 100);
    final fresh = _path('fresh', featured: true);

    final result = buildForYouPaths(
      state: _state([mine, fresh]),
      fellowshipCompletedPathIds: const {},
      fellowshipPath: null,
      minCount: 3,
    );

    expect(result.map((p) => p.id), ['fresh']);
  });

  test('the fellowship active path leads when it is not already listed', () {
    // The fellowship path is fetched separately when its category has not
    // loaded, so it is absent from the listing.
    final inProgress = _path('in-progress', progress: 40);
    final active = _path('active');

    final result = buildForYouPaths(
      state: _state([inProgress, _path('fresh', featured: true)]),
      fellowshipCompletedPathIds: const {},
      fellowshipPath: active,
      minCount: 2,
    );

    expect(result.first.id, 'active');
    expect(result.map((p) => p.id), contains('in-progress'));
  });
}
