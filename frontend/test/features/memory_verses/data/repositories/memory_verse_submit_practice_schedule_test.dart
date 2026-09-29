import 'package:disciplefy_bible_study/features/memory_verses/data/models/memory_verse_model.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/repositories/memory_verse_repository_impl.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/submit_practice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'memory_verse_reset_failure_test.mocks.dart';

/// The practice endpoint answers with the rescheduled review state, not the
/// verse; the repository applies it to the cached verse so the results page
/// can show "Next review in N days".
void main() {
  late MockMemoryVerseRemoteDataSource remote;
  late MockMemoryVerseLocalDataSource local;
  late MemoryVerseRepositoryImpl repository;

  final cached = MemoryVerseModel(
    id: 'v1',
    verseReference: 'Philippians 4:13',
    verseText: 'I can do all things through him who strengthens me.',
    language: 'en',
    sourceType: 'manual',
    easeFactor: 2.5,
    intervalDays: 1,
    repetitions: 1,
    nextReviewDate: DateTime.utc(2026, 9, 30),
    addedDate: DateTime.utc(2026, 9),
    totalReviews: 3,
    createdAt: DateTime.utc(2026, 9),
  );

  const params = SubmitPracticeSessionParams(
    memoryVerseId: 'v1',
    practiceMode: PracticeModeType.flipCard,
    qualityRating: 4,
    confidenceRating: 4,
    timeSpentSeconds: 30,
  );

  void stubSubmit(Map<String, dynamic> response) {
    when(remote.submitPracticeSession(
      memoryVerseId: anyNamed('memoryVerseId'),
      practiceMode: anyNamed('practiceMode'),
      qualityRating: anyNamed('qualityRating'),
      confidenceRating: anyNamed('confidenceRating'),
      accuracyPercentage: anyNamed('accuracyPercentage'),
      timeSpentSeconds: anyNamed('timeSpentSeconds'),
      hintsUsed: anyNamed('hintsUsed'),
    )).thenAnswer((_) async => response);
  }

  setUp(() {
    remote = MockMemoryVerseRemoteDataSource();
    local = MockMemoryVerseLocalDataSource();
    repository = MemoryVerseRepositoryImpl(
      localDataSource: local,
      remoteDataSource: remote,
    );
    when(local.cacheVerse(any)).thenAnswer((_) async {});
  });

  test('returns the cached verse rescheduled to next_review_date', () async {
    stubSubmit({
      'success': true,
      'next_review_date': '2026-10-06T00:00:00.000Z',
      'interval_days': 6,
      'ease_factor': 2, // an int from JSON must not break parsing
      'repetitions': 2,
      'total_reviews': 4,
      'xp_earned': 10,
    });
    when(local.getCachedVerseById('v1')).thenAnswer((_) async => cached);

    final result = await repository.submitPracticeSession(params);

    final response = result.getOrElse(() => throw StateError('failed'));
    final verse = response.updatedVerse!;
    expect(verse.id, 'v1');
    expect(verse.nextReviewDate, DateTime.utc(2026, 10, 6));
    expect(verse.intervalDays, 6);
    expect(verse.easeFactor, 2.0);
    expect(verse.totalReviews, 4);
    expect(response.xpEarned, 10);
    verify(local.cacheVerse(argThat(
      isA<MemoryVerseModel>()
          .having((v) => v.nextReviewDate, 'next', DateTime.utc(2026, 10, 6)),
    ))).called(1);
  });

  test('succeeds without a verse when it is not cached', () async {
    stubSubmit({
      'next_review_date': '2026-10-06T00:00:00.000Z',
      'xp_earned': 10,
    });
    when(local.getCachedVerseById('v1')).thenAnswer((_) async => null);

    final result = await repository.submitPracticeSession(params);

    expect(result.isRight(), isTrue);
    expect(result.getOrElse(() => throw StateError('failed')).updatedVerse,
        isNull);
  });

  test('a failing cache never fails the saved session', () async {
    stubSubmit({
      'next_review_date': '2026-10-06T00:00:00.000Z',
      'xp_earned': 10,
    });
    when(local.getCachedVerseById('v1')).thenThrow(Exception('hive'));

    final result = await repository.submitPracticeSession(params);

    expect(result.isRight(), isTrue);
  });
}
