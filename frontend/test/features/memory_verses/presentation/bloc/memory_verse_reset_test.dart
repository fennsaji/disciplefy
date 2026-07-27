import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/memory_verse_notification_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/suggested_verses_cache_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/repositories/memory_verse_repository.dart';
// Aliased: these use case class names collide with event classes of the
// same name declared in memory_verse_event.dart (imported below).
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/add_verse_from_daily.dart'
    as add_from_daily_uc;
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/add_verse_manually.dart'
    as add_manually_uc;
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/claim_challenge_reward.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/delete_verse.dart'
    as delete_verse_uc;
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/fetch_verse_text.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_active_challenges.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_cached_due_verses.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_daily_goal.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_due_verses.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_mastery_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_memory_champions_leaderboard.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_memory_statistics.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_memory_streak.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_practice_mode_statistics.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_statistics.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_suggested_verses.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/reset_memory_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/select_practice_mode.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/set_daily_goal_targets.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/submit_practice_session.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/submit_review.dart'
    as submit_review_uc;
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/update_daily_goal_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/update_mastery_level.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/use_streak_freeze.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'memory_verse_reset_test.mocks.dart';

/// ConnectivityBloc is listened to in MemoryVerseBloc's constructor, so it
/// needs a real stream. MockBloc from bloc_test provides one.
class MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

@GenerateNiceMocks([
  MockSpec<MemoryVerseRepository>(),
  MockSpec<GetDueVerses>(),
  MockSpec<GetCachedDueVerses>(),
  MockSpec<add_from_daily_uc.AddVerseFromDaily>(),
  MockSpec<add_manually_uc.AddVerseManually>(),
  MockSpec<submit_review_uc.SubmitReview>(),
  MockSpec<GetStatistics>(),
  MockSpec<FetchVerseText>(),
  MockSpec<delete_verse_uc.DeleteVerse>(),
  MockSpec<SelectPracticeMode>(),
  MockSpec<SubmitPracticeSession>(),
  MockSpec<GetPracticeModeStatistics>(),
  MockSpec<GetMemoryStreak>(),
  MockSpec<UseStreakFreeze>(),
  MockSpec<GetMasteryProgress>(),
  MockSpec<UpdateMasteryLevel>(),
  MockSpec<GetDailyGoal>(),
  MockSpec<UpdateDailyGoalProgress>(),
  MockSpec<SetDailyGoalTargets>(),
  MockSpec<GetActiveChallenges>(),
  MockSpec<ClaimChallengeReward>(),
  MockSpec<GetMemoryChampionsLeaderboard>(),
  MockSpec<GetMemoryStatistics>(),
  MockSpec<GetSuggestedVerses>(),
  MockSpec<MemoryVerseNotificationService>(),
  MockSpec<SuggestedVersesCacheService>(),
])
void main() {
  late MockMemoryVerseRepository repository;
  late MockConnectivityBloc connectivityBloc;

  setUp(() {
    repository = MockMemoryVerseRepository();
    connectivityBloc = MockConnectivityBloc();
    whenListen(
      connectivityBloc,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityInitial(),
    );
  });

  const resetResult = ResetProgressResult(
    scope: 'memory_verses',
    counts: {'verses_deleted': 42},
  );

  /// Builds the bloc with nice mocks everywhere except the reset use case,
  /// which is real so the repository call is actually exercised.
  MemoryVerseBloc buildBloc() => MemoryVerseBloc(
        getDueVerses: MockGetDueVerses(),
        getCachedDueVerses: MockGetCachedDueVerses(),
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
        getMasteryProgress: MockGetMasteryProgress(),
        updateMasteryLevel: MockUpdateMasteryLevel(),
        getDailyGoal: MockGetDailyGoal(),
        updateDailyGoalProgress: MockUpdateDailyGoalProgress(),
        setDailyGoalTargets: MockSetDailyGoalTargets(),
        getActiveChallenges: MockGetActiveChallenges(),
        claimChallengeReward: MockClaimChallengeReward(),
        getMemoryChampionsLeaderboard: MockGetMemoryChampionsLeaderboard(),
        getMemoryStatistics: MockGetMemoryStatistics(),
        getSuggestedVerses: MockGetSuggestedVerses(),
        notificationService: MockMemoryVerseNotificationService(),
        suggestedVersesCacheService: MockSuggestedVersesCacheService(),
        connectivityBloc: connectivityBloc,
        resetMemoryProgress: ResetMemoryProgress(repository),
      );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'emits [Resetting, ResetSuccess] when the reset succeeds',
    build: () {
      when(repository.resetMemoryProgress())
          .thenAnswer((_) async => const Right(resetResult));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetMemoryProgressRequested()),
    expect: () => [
      const MemoryProgressResetting(),
      const MemoryProgressResetSuccess(result: resetResult),
    ],
    verify: (_) {
      verify(repository.resetMemoryProgress()).called(1);
    },
  );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'emits [Resetting, ResetError] when the reset fails',
    build: () {
      when(repository.resetMemoryProgress()).thenAnswer(
        (_) async => const Left(
          NetworkFailure(message: 'offline'),
        ),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetMemoryProgressRequested()),
    expect: () => [
      const MemoryProgressResetting(),
      isA<MemoryProgressResetError>(),
    ],
    verify: (_) {
      verify(repository.resetMemoryProgress()).called(1);
    },
  );
}
