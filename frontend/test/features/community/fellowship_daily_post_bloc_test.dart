import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/daily_post_status_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_daily_post/fellowship_daily_post_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_daily_post/fellowship_daily_post_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_daily_post/fellowship_daily_post_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves queued status responses in order and records schedule changes.
class _FakeRepository extends Fake implements CommunityRepository {
  final List<Either<Failure, DailyPostStatusEntity>> statuses;
  Either<Failure, void> updateResult = const Right(null);
  Either<Failure, void> requestResult = const Right(null);
  final List<String> requestedKinds = [];

  _FakeRepository(this.statuses);

  @override
  Future<Either<Failure, DailyPostStatusEntity>> getDailyPostStatus(
      String fellowshipId) async {
    return statuses.length > 1 ? statuses.removeAt(0) : statuses.first;
  }

  @override
  Future<Either<Failure, void>> updateDailyPost(
    String fellowshipId, {
    bool? skipNext,
    String? pausedUntil,
    bool clearPause = false,
    String? time,
    String? nextLearningPathTopicId,
  }) async =>
      updateResult;

  final List<Map<String, Object?>> fellowshipUpdates = [];

  @override
  Future<Either<Failure, void>> updateFellowship({
    required String fellowshipId,
    String? name,
    String? description,
    int? maxMembers,
    String? postingPermission,
    bool? isOfficial,
    bool? disciplerAllowed,
    bool? dailyPostAllowed,
    String? disciplerReplyMode,
    String? disciplerReplyScope,
    int? disciplerReplyDelayMin,
    bool? disciplerReactEnabled,
    bool? dailyPostOn,
    int? dailyPostFrequencyDays,
    bool? dailyPostAutoAdvance,
    bool? dailyPostAutoAdvancePath,
    bool? disciplerActivityPush,
    bool? notificationsMuted,
  }) async {
    fellowshipUpdates.add({
      'fellowshipId': fellowshipId,
      'dailyPostOn': dailyPostOn,
      'dailyPostFrequencyDays': dailyPostFrequencyDays,
      'dailyPostAutoAdvance': dailyPostAutoAdvance,
    });
    return updateResult;
  }

  @override
  Future<Either<Failure, void>> requestDailyPostAction(
      String fellowshipId, String kind,
      {String? dailyPostId}) async {
    requestedKinds.add(kind);
    return requestResult;
  }
}

DailyPostStatusEntity _status(
        {Map<String, DailyPostRequestEntity>? requests}) =>
    DailyPostStatusEntity(
      settings: const DailyPostSettingsEntity(
        dailyPostOn: true,
        frequencyDays: 1,
        autoAdvance: true,
        time: '06:30',
        previewAllowed: true,
      ),
      today: '2026-09-14',
      requests: requests ?? const {},
    );

const _openPreview =
    DailyPostRequestEntity(kind: 'preview', status: 'processing');

void main() {
  const fellowshipId = 'f-1';

  blocTest<FellowshipDailyPostBloc, FellowshipDailyPostState>(
    'shows the load error when the status cannot be loaded',
    build: () => FellowshipDailyPostBloc(
      repository: _FakeRepository(
          [const Left(ServerFailure(message: 'Mentor access required'))]),
    ),
    act: (bloc) =>
        bloc.add(const FellowshipDailyPostLoadRequested(fellowshipId)),
    expect: () => [
      isA<FellowshipDailyPostState>()
          .having((s) => s.status, 'status', FellowshipDailyPostStatus.loading),
      isA<FellowshipDailyPostState>()
          .having((s) => s.status, 'status', FellowshipDailyPostStatus.failure),
    ],
  );

  blocTest<FellowshipDailyPostBloc, FellowshipDailyPostState>(
    'raises a success notice when an open request finishes',
    build: () => FellowshipDailyPostBloc(
      repository: _FakeRepository([
        Right(_status(requests: {'preview': _openPreview})),
        Right(_status(requests: {
          'preview':
              const DailyPostRequestEntity(kind: 'preview', status: 'done'),
        })),
      ]),
    ),
    act: (bloc) async {
      bloc.add(const FellowshipDailyPostLoadRequested(fellowshipId));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FellowshipDailyPostRefreshRequested());
    },
    skip: 2,
    expect: () => [
      isA<FellowshipDailyPostState>()
          .having((s) => s.notice?.kind, 'notice kind', 'preview')
          .having((s) => s.notice?.success, 'notice success', true),
    ],
  );

  blocTest<FellowshipDailyPostBloc, FellowshipDailyPostState>(
    'shows the server message when a request fails',
    build: () => FellowshipDailyPostBloc(
      repository: _FakeRepository([
        Right(_status(requests: {'preview': _openPreview})),
        Right(_status(requests: {
          'preview': const DailyPostRequestEntity(
              kind: 'preview',
              status: 'failed',
              error: 'Preview the next post first.'),
        })),
      ]),
    ),
    act: (bloc) async {
      bloc.add(const FellowshipDailyPostLoadRequested(fellowshipId));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FellowshipDailyPostRefreshRequested());
    },
    skip: 2,
    expect: () => [
      isA<FellowshipDailyPostState>()
          .having((s) => s.notice?.success, 'notice success', false)
          .having((s) => s.notice?.error, 'notice error',
              'Preview the next post first.'),
    ],
  );

  blocTest<FellowshipDailyPostBloc, FellowshipDailyPostState>(
    'a rejected schedule change raises a failure notice with the server message',
    build: () {
      final repo = _FakeRepository([Right(_status())])
        // The repository maps a server-explained rule to ValidationFailure.
        ..updateResult = const Left(ValidationFailure(
            message: 'Daily posts can be paused for up to 90 days'));
      return FellowshipDailyPostBloc(repository: repo);
    },
    act: (bloc) async {
      bloc.add(const FellowshipDailyPostLoadRequested(fellowshipId));
      await Future<void>.delayed(Duration.zero);
      bloc.add(
          const FellowshipDailyPostScheduleChanged(pausedUntil: '2027-01-01'));
    },
    skip: 3,
    expect: () => [
      isA<FellowshipDailyPostState>()
          .having((s) => s.saving, 'saving', false)
          .having((s) => s.notice?.kind, 'notice kind', 'schedule')
          .having((s) => s.notice?.error, 'notice error',
              'Daily posts can be paused for up to 90 days'),
    ],
  );

  final settingsRepo = _FakeRepository([Right(_status())]);
  blocTest<FellowshipDailyPostBloc, FellowshipDailyPostState>(
    'a settings change updates only that fellowship field',
    build: () => FellowshipDailyPostBloc(repository: settingsRepo),
    act: (bloc) async {
      bloc.add(const FellowshipDailyPostLoadRequested(fellowshipId));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FellowshipDailyPostSettingsChanged(frequencyDays: 7));
    },
    skip: 3,
    expect: () => [
      isA<FellowshipDailyPostState>()
          .having((s) => s.notice?.kind, 'notice kind', 'schedule')
          .having((s) => s.notice?.success, 'notice success', true),
    ],
    verify: (_) => expect(settingsRepo.fellowshipUpdates, [
      {
        'fellowshipId': fellowshipId,
        'dailyPostOn': null,
        'dailyPostFrequencyDays': 7,
        'dailyPostAutoAdvance': null,
      }
    ]),
  );
}
