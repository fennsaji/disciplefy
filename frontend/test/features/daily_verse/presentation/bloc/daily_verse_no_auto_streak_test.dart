import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/usecases/usecase.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_streak.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/repositories/streak_repository.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/usecases/get_cached_verse.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/usecases/get_daily_verse.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/usecases/get_default_language.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/usecases/manage_verse_preferences.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetDailyVerse extends Mock implements GetDailyVerse {}

class _MockGetCachedVerse extends Mock implements GetCachedVerse {}

class _MockGetPreferredLanguage extends Mock implements GetPreferredLanguage {}

class _MockSetPreferredLanguage extends Mock implements SetPreferredLanguage {}

class _MockGetCacheStats extends Mock implements GetCacheStats {}

class _MockClearVerseCache extends Mock implements ClearVerseCache {}

class _MockGetDefaultLanguage extends Mock implements GetDefaultLanguage {}

class _MockLanguageService extends Mock implements LanguagePreferenceService {}

class _MockStreakRepository extends Mock implements StreakRepository {}

final DailyVerseEntity todayVerse = DailyVerseEntity(
  id: 'verse-1',
  reference: 'John 3:16',
  referenceTranslations: const ReferenceTranslations(
    en: 'John 3:16',
    hi: 'यूहन्ना 3:16',
    ml: 'യോഹന്നാൻ 3:16',
  ),
  translations: const DailyVerseTranslations(
    esv: 'For God so loved the world',
    hindi: 'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा',
    malayalam: 'തന്റെ ഏകജാതനായ പുത്രനെ',
  ),
  date: DateTime.now(),
);

DailyVerseStreak _streak(int current) => DailyVerseStreak(
      userId: 'u1',
      currentStreak: current,
      longestStreak: current,
      lastViewedAt: DateTime.now(),
      totalViews: current,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(GetDailyVerseParams.today(VerseLanguage.english));
    registerFallbackValue(NoParams());
  });

  late _MockStreakRepository mockStreakRepo;
  late StreamController<AppLanguage> languageChanges;

  DailyVerseBloc buildBloc({
    required StreakRepository streakRepository,
    required DailyVerseEntity verse,
  }) {
    final getDailyVerse = _MockGetDailyVerse();
    final getDefaultLanguage = _MockGetDefaultLanguage();
    final languageService = _MockLanguageService();
    when(() => languageService.languageChanges)
        .thenAnswer((_) => languageChanges.stream);
    when(() => languageService.studyContentLanguageChanges)
        .thenAnswer((_) => languageChanges.stream);
    when(() => getDefaultLanguage(any()))
        .thenAnswer((_) async => const Right(VerseLanguage.english));
    when(() => getDailyVerse(any())).thenAnswer((_) async => Right(verse));
    return DailyVerseBloc(
      getDailyVerse: getDailyVerse,
      getCachedVerse: _MockGetCachedVerse(),
      getPreferredLanguage: _MockGetPreferredLanguage(),
      setPreferredLanguage: _MockSetPreferredLanguage(),
      getCacheStats: _MockGetCacheStats(),
      clearVerseCache: _MockClearVerseCache(),
      getDefaultLanguage: getDefaultLanguage,
      languagePreferenceService: languageService,
      streakRepository: streakRepository,
    );
  }

  setUp(() {
    languageChanges = StreamController<AppLanguage>.broadcast();
    mockStreakRepo = _MockStreakRepository();
    when(() => mockStreakRepo.getStreak()).thenAnswer((_) async => _streak(2));
    when(() => mockStreakRepo.markVerseAsViewed())
        .thenAnswer((_) async => _streak(3));
  });

  tearDown(() => languageChanges.close());

  blocTest<DailyVerseBloc, DailyVerseState>(
    'loading today\'s verse does not touch the streak',
    build: () => buildBloc(streakRepository: mockStreakRepo, verse: todayVerse),
    act: (b) => b.add(const LoadTodaysVerse()),
    wait: const Duration(milliseconds: 50),
    verify: (_) => verifyNever(() => mockStreakRepo.markVerseAsViewed()),
  );

  blocTest<DailyVerseBloc, DailyVerseState>(
    'reading the verse counts once per day, however often the UI reports it',
    build: () => buildBloc(streakRepository: mockStreakRepo, verse: todayVerse),
    act: (b) async {
      b.add(const LoadTodaysVerse());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b
        ..add(const MarkVerseAsViewed())
        ..add(const MarkVerseAsViewed());
    },
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      verify(() => mockStreakRepo.markVerseAsViewed()).called(1);
      expect((b.state as DailyVerseLoaded).streak?.currentStreak, 3);
    },
  );

  blocTest<DailyVerseBloc, DailyVerseState>(
    'a failed mark is retried by the next read',
    build: () {
      var calls = 0;
      when(() => mockStreakRepo.markVerseAsViewed()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return _streak(3);
      });
      return buildBloc(streakRepository: mockStreakRepo, verse: todayVerse);
    },
    act: (b) async {
      b.add(const LoadTodaysVerse());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b
        ..add(const MarkVerseAsViewed())
        ..add(const MarkVerseAsViewed());
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) => verify(() => mockStreakRepo.markVerseAsViewed()).called(2),
  );
}
