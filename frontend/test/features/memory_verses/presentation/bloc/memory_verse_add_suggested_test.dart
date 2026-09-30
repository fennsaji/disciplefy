import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/reset_memory_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'memory_verse_reset_test.mocks.dart';

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

void main() {
  late MockAddVerseManually addVerseManually;
  late MockSuggestedVersesCacheService cache;
  late _MockConnectivityBloc connectivityBloc;

  setUp(() {
    addVerseManually = MockAddVerseManually();
    cache = MockSuggestedVersesCacheService();
    when(cache.clearCache()).thenAnswer((_) async {});
    connectivityBloc = _MockConnectivityBloc();
    whenListen(connectivityBloc, const Stream<ConnectivityState>.empty(),
        initialState: ConnectivityInitial());
  });

  MemoryVerseBloc buildBloc() => MemoryVerseBloc(
        getDueVerses: MockGetDueVerses(),
        getCachedDueVerses: MockGetCachedDueVerses(),
        addVerseFromDaily: MockAddVerseFromDaily(),
        addVerseManually: addVerseManually,
        submitReview: MockSubmitReview(),
        getStatistics: MockGetStatistics(),
        fetchVerseText: MockFetchVerseText(),
        deleteVerse: MockDeleteVerse(),
        selectPracticeMode: MockSelectPracticeMode(),
        submitPracticeSession: MockSubmitPracticeSession(),
        getPracticeModeStatistics: MockGetPracticeModeStatistics(),
        getMemoryStreak: MockGetMemoryStreak(),
        useStreakFreeze: MockUseStreakFreeze(),
        getDailyGoal: MockGetDailyGoal(),
        getActiveChallenges: MockGetActiveChallenges(),
        getMemoryChampionsLeaderboard: MockGetMemoryChampionsLeaderboard(),
        getMemoryStatistics: MockGetMemoryStatistics(),
        getSuggestedVerses: MockGetSuggestedVerses(),
        notificationService: MockMemoryVerseNotificationService(),
        suggestedVersesCacheService: cache,
        connectivityBloc: connectivityBloc,
        resetMemoryProgress: ResetMemoryProgress(MockMemoryVerseRepository()),
      );

  const event = AddSuggestedVerseEvent(
    verseReference: 'John 3:16',
    verseText: 'For God so loved the world that he gave',
    language: 'en',
  );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'a stale "not added" flag (409) keeps VERSE_ALREADY_EXISTS and clears the suggested cache',
    build: () {
      when(addVerseManually(
        verseReference: anyNamed('verseReference'),
        verseText: anyNamed('verseText'),
        language: anyNamed('language'),
      )).thenAnswer((_) async => const Left(ServerFailure(
          message: 'This verse is already in your memory deck',
          code: 'VERSE_ALREADY_EXISTS')));
      return buildBloc();
    },
    act: (bloc) => bloc.add(event),
    expect: () => [
      isA<MemoryVerseLoading>(),
      isA<MemoryVerseError>()
          .having((s) => s.code, 'code', 'VERSE_ALREADY_EXISTS'),
    ],
    verify: (_) => verify(cache.clearCache()).called(1),
  );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'an offline add emits OperationQueued',
    build: () {
      when(addVerseManually(
        verseReference: anyNamed('verseReference'),
        verseText: anyNamed('verseText'),
        language: anyNamed('language'),
      )).thenAnswer((_) async => const Left(
          NetworkFailure(message: 'queued', code: 'OFFLINE_QUEUED')));
      return buildBloc();
    },
    act: (bloc) => bloc.add(event),
    expect: () => [isA<MemoryVerseLoading>(), isA<OperationQueued>()],
  );
}
