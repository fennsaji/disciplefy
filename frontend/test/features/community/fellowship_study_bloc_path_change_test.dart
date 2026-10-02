// Changing a fellowship's learning path starts the group at the new path's
// first lesson: the previous path's lesson index and length never carry over.

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';

class _MockRepository extends Mock implements CommunityRepository {}

class _MockLanguagePrefs extends Mock implements LanguagePreferenceService {}

void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    final prefs = _MockLanguagePrefs();
    when(prefs.getStudyContentLanguage)
        .thenAnswer((_) async => AppLanguage.english);
    sl.registerSingleton<LanguagePreferenceService>(prefs);
    when(() => repository.setFellowshipStudy(
          fellowshipId: any(named: 'fellowshipId'),
          learningPathId: any(named: 'learningPathId'),
        )).thenAnswer((_) async => const Right('Rooted in Christ'));
    when(() => repository.getFellowship(any(), any()))
        .thenAnswer((_) async => const Right({
              'language': 'en',
              'name': 'Group',
              'active_study': {
                'learning_path_id': 'rooted',
                'learning_path_title': 'Rooted in Christ',
                'current_guide_index': 0,
                'total_guides': 5,
              },
            }));
  });

  tearDown(() => sl.reset());

  // The group was on lesson 8 of 8 of its previous path.
  const onOldPath = FellowshipStudyState(
    fellowshipId: 'f1',
    isMentor: true,
    currentLearningPathId: 'nbe',
    currentPathTitle: 'New Believer Essentials',
    currentGuideIndex: 7,
    totalGuides: 8,
  );

  blocTest<FellowshipStudyBloc, FellowshipStudyState>(
    'a new path starts at lesson 1 and loads its own length',
    build: () => FellowshipStudyBloc(repository: repository),
    seed: () => onOldPath,
    act: (bloc) => bloc.add(const FellowshipStudySetRequested(
      fellowshipId: 'f1',
      learningPathId: 'rooted',
      learningPathTitle: 'Rooted in Christ',
    )),
    verify: (bloc) {
      verify(() => repository.getFellowship('f1', 'en')).called(1);
      final s = bloc.state;
      expect(s.setStatus, FellowshipStudySetStatus.success);
      expect(s.currentLearningPathId, 'rooted');
      expect(s.currentGuideIndex, 0);
      expect(s.totalGuides, 5);
      expect(s.studyCompleted, isFalse);
    },
  );

  blocTest<FellowshipStudyBloc, FellowshipStudyState>(
    'the old path length is dropped as soon as the path changes',
    build: () => FellowshipStudyBloc(repository: repository),
    seed: () => onOldPath,
    setUp: () => when(() => repository.getFellowship(any(), any()))
        .thenAnswer((_) async => const Right(<String, dynamic>{})),
    act: (bloc) => bloc.add(const FellowshipStudySetRequested(
      fellowshipId: 'f1',
      learningPathId: 'rooted',
      learningPathTitle: 'Rooted in Christ',
    )),
    verify: (bloc) {
      expect(bloc.state.currentGuideIndex, 0);
      expect(bloc.state.totalGuides, isNull);
    },
  );

  blocTest<FellowshipStudyBloc, FellowshipStudyState>(
    'a finished path is restored as finished, not as no study',
    build: () => FellowshipStudyBloc(repository: repository),
    seed: () => const FellowshipStudyState(fellowshipId: 'f1'),
    setUp: () => when(() => repository.getFellowship(any(), any()))
        .thenAnswer((_) async => const Right({
              'active_study': null,
              'finished_study': {
                'learning_path_id': 'rooted',
                'learning_path_title': 'Rooted in Christ',
                'current_guide_index': 4,
                'completed_at': '2026-10-02T05:00:00Z',
                'total_guides': 5,
              },
            })),
    act: (bloc) => bloc.add(const FellowshipStudyRefreshRequested()),
    verify: (bloc) {
      final s = bloc.state;
      expect(s.currentLearningPathId, 'rooted');
      expect(s.totalGuides, 5);
      expect(s.studyCompleted, isTrue);
    },
  );

  blocTest<FellowshipStudyBloc, FellowshipStudyState>(
    'an active study clears an earlier finished state',
    build: () => FellowshipStudyBloc(repository: repository),
    seed: () => onOldPath.copyWith(studyCompleted: true),
    act: (bloc) => bloc.add(const FellowshipStudyRefreshRequested()),
    verify: (bloc) {
      expect(bloc.state.currentLearningPathId, 'rooted');
      expect(bloc.state.studyCompleted, isFalse);
    },
  );

  blocTest<FellowshipStudyBloc, FellowshipStudyState>(
    'initial state from a cached finished study is finished',
    build: () => FellowshipStudyBloc(repository: repository),
    act: (bloc) => bloc.add(const FellowshipStudyInitialized(
      fellowshipId: 'f1',
      isMentor: true,
      currentLearningPathId: 'rooted',
      currentGuideIndex: 4,
      currentTotalGuides: 5,
      studyCompleted: true,
    )),
    verify: (bloc) => expect(bloc.state.studyCompleted, isTrue),
  );
}
