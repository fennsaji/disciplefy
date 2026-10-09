// Memory verses need an account: a guest's Home must not call
// get-due-memory-verses (403 ACCOUNT_REQUIRED), and that failure is never
// shown as an error.

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/error/account_required.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
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
  late MockGetDueVerses getDueVerses;
  late MockGetCachedDueVerses getCachedDueVerses;
  late _MockConnectivityBloc connectivityBloc;

  setUp(() {
    getDueVerses = MockGetDueVerses();
    getCachedDueVerses = MockGetCachedDueVerses();
    when(getCachedDueVerses(language: anyNamed('language')))
        .thenAnswer((_) async => null);
    connectivityBloc = _MockConnectivityBloc();
    whenListen(connectivityBloc, const Stream<ConnectivityState>.empty(),
        initialState: ConnectivityInitial());
  });

  MemoryVerseBloc buildBloc({required bool guest}) => MemoryVerseBloc(
        getDueVerses: getDueVerses,
        getCachedDueVerses: getCachedDueVerses,
        addVerseFromDaily: MockAddVerseFromDaily(),
        addVerseManually: MockAddVerseManually(),
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
        suggestedVersesCacheService: MockSuggestedVersesCacheService(),
        connectivityBloc: connectivityBloc,
        resetMemoryProgress: ResetMemoryProgress(MockMemoryVerseRepository()),
        isGuest: () => guest,
      );

  const stats = ReviewStatisticsEntity(
    totalVerses: 0,
    dueVerses: 0,
    reviewedToday: 0,
    upcomingReviews: 0,
    masteredVerses: 0,
    fullyMasteredVerses: 0,
  );

  void stubDue(Failure? failure) {
    when(getDueVerses(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      language: anyNamed('language'),
    )).thenAnswer((_) async => failure != null
        ? Left(failure)
        : const Right((<MemoryVerseEntity>[], stats)));
  }

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'guest: LoadDueVerses never calls the server and emits nothing',
    build: () => buildBloc(guest: true),
    act: (bloc) => bloc
      ..add(const LoadDueVerses())
      ..add(const SyncWithRemote()),
    expect: () => <MemoryVerseState>[],
    verify: (_) {
      verifyNever(getDueVerses(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        language: anyNamed('language'),
      ));
      verifyNever(getCachedDueVerses(language: anyNamed('language')));
    },
  );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'full user: LoadDueVerses still loads the due list',
    build: () {
      stubDue(null);
      return buildBloc(guest: false);
    },
    act: (bloc) => bloc.add(const LoadDueVerses()),
    expect: () => [isA<DueVersesLoaded>()],
    verify: (_) => verify(getDueVerses(
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
      language: anyNamed('language'),
    )).called(1),
  );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'ACCOUNT_REQUIRED from the server is not an error state',
    build: () {
      stubDue(const ServerFailure(
          message: 'Create an account', code: accountRequiredCode));
      return buildBloc(guest: false);
    },
    act: (bloc) => bloc.add(const LoadDueVerses()),
    expect: () => <MemoryVerseState>[],
  );

  group('isAccountRequired', () {
    test('typed failure', () {
      expect(isAccountRequired(const AccountRequiredFailure()), isTrue);
    });
    test('generic failure carrying the code', () {
      expect(
          isAccountRequired(
              const ServerFailure(message: 'x', code: 'ACCOUNT_REQUIRED')),
          isTrue);
    });
    test('other failures', () {
      expect(isAccountRequired(const ServerFailure(message: 'x')), isFalse);
      expect(isAccountRequired(const NetworkFailure()), isFalse);
    });
  });
}
