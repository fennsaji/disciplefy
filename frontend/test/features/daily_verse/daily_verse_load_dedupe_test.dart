import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/usecases/usecase.dart';
import 'package:disciplefy_bible_study/features/daily_verse/data/repositories/daily_verse_repository_impl.dart';
import 'package:disciplefy_bible_study/features/daily_verse/data/services/daily_verse_api_service.dart';
import 'package:disciplefy_bible_study/features/daily_verse/data/services/daily_verse_cache_interface.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
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

class _MockApi extends Mock implements DailyVerseApiService {}

class _MockCache extends Mock implements DailyVerseCacheInterface {}

DailyVerseEntity _todaysVerse() => DailyVerseEntity(
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

void main() {
  setUpAll(() {
    registerFallbackValue(GetDailyVerseParams.today(VerseLanguage.english));
    registerFallbackValue(NoParams());
  });

  group('DailyVerseBloc', () {
    late _MockGetDailyVerse getDailyVerse;
    late _MockGetDefaultLanguage getDefaultLanguage;
    late _MockLanguageService languageService;
    late _MockStreakRepository streakRepository;
    late StreamController<AppLanguage> appLanguage;
    late StreamController<AppLanguage> contentLanguage;
    late DailyVerseBloc bloc;
    var language = VerseLanguage.english;

    setUp(() {
      language = VerseLanguage.english;
      appLanguage = StreamController<AppLanguage>.broadcast();
      contentLanguage = StreamController<AppLanguage>.broadcast();
      getDailyVerse = _MockGetDailyVerse();
      getDefaultLanguage = _MockGetDefaultLanguage();
      languageService = _MockLanguageService();
      streakRepository = _MockStreakRepository();

      when(() => languageService.languageChanges)
          .thenAnswer((_) => appLanguage.stream);
      when(() => languageService.studyContentLanguageChanges)
          .thenAnswer((_) => contentLanguage.stream);
      when(() => getDefaultLanguage(any()))
          .thenAnswer((_) async => Right(language));
      when(() => getDailyVerse(any()))
          .thenAnswer((_) async => Right(_todaysVerse()));
      when(() => streakRepository.getStreak()).thenAnswer((_) async => null);
      when(() => streakRepository.markVerseAsViewed())
          .thenThrow(Exception('not signed in'));

      bloc = DailyVerseBloc(
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
    });

    tearDown(() async {
      await bloc.close();
      await appLanguage.close();
      await contentLanguage.close();
    });

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('launch requests from main.dart and Home collapse into one load',
        () async {
      bloc
        ..add(const LoadTodaysVerse())
        ..add(const LoadTodaysVerse());
      await settle();

      verify(() => getDailyVerse(any())).called(1);
      verify(() => streakRepository.getStreak()).called(1);
      expect(bloc.state, isA<DailyVerseLoaded>());
    });

    test('a forced refresh still runs while a load is in flight', () async {
      bloc
        ..add(const LoadTodaysVerse())
        ..add(const LoadTodaysVerse(forceRefresh: true));
      await settle();

      verify(() => getDailyVerse(any())).called(2);
    });

    test('a later load (e.g. after sign-in) is not dropped', () async {
      bloc.add(const LoadTodaysVerse());
      await settle();
      bloc.add(const LoadTodaysVerse());
      await settle();

      verify(() => getDailyVerse(any())).called(2);
    });

    test(
        'a language switch shows today\'s verse in the new language at once, '
        'without a network call or a loading state', () async {
      bloc.add(const LoadTodaysVerse());
      await settle();
      clearInteractions(getDailyVerse);

      final states = <DailyVerseState>[];
      final sub = bloc.stream.listen(states.add);
      language = VerseLanguage.hindi;
      // Both streams fire for one change.
      appLanguage.add(AppLanguage.hindi);
      contentLanguage.add(AppLanguage.hindi);
      await settle();
      await sub.cancel();

      verifyNever(() => getDailyVerse(any()));
      expect(states.whereType<DailyVerseLoading>(), isEmpty);
      final loaded = bloc.state as DailyVerseLoaded;
      expect(loaded.currentLanguage, VerseLanguage.hindi);
      expect(loaded.verse.id, 'verse-1');
    });
  });

  group('DailyVerseRepositoryImpl', () {
    late _MockApi api;
    late _MockCache cache;
    late DailyVerseRepositoryImpl repository;

    setUp(() {
      api = _MockApi();
      cache = _MockCache();
      repository =
          DailyVerseRepositoryImpl(apiService: api, cacheService: cache);
    });

    test(
        'today\'s cached verse is served in every language with no network '
        'call (it carries all translations)', () async {
      final verse = _todaysVerse();
      when(() => cache.shouldRefresh()).thenAnswer((_) async => false);
      when(() => cache.getCachedVerse(any())).thenAnswer((_) async => verse);

      for (final language in VerseLanguage.values) {
        final result = await repository.getTodaysVerse(language);
        final served = result.getOrElse(() => throw 'x');
        expect(served.getVerseText(language), isNotEmpty);
      }
      verifyNever(() => api.getDailyVerse(any(), any()));
    });
  });
}
