import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/locale_service.dart';

import 'content_language_independence_test.mocks.dart';

/// The selected-language cache: callers are answered from memory or local
/// storage, the profile request is shared and runs in the background, and the
/// cache never outlives a language change, logout or user switch.
void main() {
  late SharedPreferences prefs;
  late MockAuthStateProvider authState;
  late MockUserProfileService profileService;
  late LanguagePreferenceService service;

  /// Each profile request waits on its own completer so a test decides when
  /// (and with what) the server answers.
  late List<Completer<Either<Failure, AppLanguage?>>> serverRequests;

  Future<void> build({String? localLanguage, String? userId = 'user-a'}) async {
    SharedPreferences.setMockInitialValues({
      if (localLanguage != null) 'user_language_preference': localLanguage,
    });
    prefs = await SharedPreferences.getInstance();

    authState = MockAuthStateProvider();
    when(authState.isAuthenticated).thenReturn(userId != null);
    when(authState.userId).thenReturn(userId);

    serverRequests = [];
    profileService = MockUserProfileService();
    when(profileService.getLanguagePreference()).thenAnswer((_) {
      final request = Completer<Either<Failure, AppLanguage?>>();
      serverRequests.add(request);
      return request.future;
    });
    when(profileService.updateLanguagePreference(any)).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'not under test')));

    service = LanguagePreferenceService(
      prefs: prefs,
      authService: MockAuthService(),
      authStateProvider: authState,
      userProfileService: profileService,
      cacheCoordinator: MockLanguageCacheCoordinator(),
    );
  }

  /// Lets the background reconcile run to completion.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  tearDown(() => service.dispose());

  group('getSelectedLanguage', () {
    test('returns the local language without waiting for the server', () async {
      await build(localLanguage: 'hi');

      final language = await service
          .getSelectedLanguage()
          .timeout(const Duration(seconds: 1));

      expect(language, AppLanguage.hindi);
      expect(serverRequests, hasLength(1),
          reason: 'server value is reconciled in the background');
    });

    test('concurrent callers share one server request', () async {
      await build(localLanguage: 'en');

      await Future.wait(List.generate(6, (_) => service.getSelectedLanguage()));
      await service.getStudyContentLanguage();

      expect(serverRequests, hasLength(1));
    });

    test('a reconciled value is served from memory (cache hit)', () async {
      await build(localLanguage: 'en');
      await service.getSelectedLanguage();
      serverRequests.single.complete(const Right(AppLanguage.english));
      await settle();

      await service.getSelectedLanguage();
      await service.getStudyContentLanguage();

      expect(serverRequests, hasLength(1), reason: 'no request while fresh');
    });

    test('a different server language replaces local and is announced',
        () async {
      await build(localLanguage: 'en');
      final announced = <AppLanguage>[];
      final sub = service.languageChanges.listen(announced.add);

      expect(await service.getSelectedLanguage(), AppLanguage.english);
      serverRequests.single.complete(const Right(AppLanguage.malayalam));
      await settle();

      expect(announced, [AppLanguage.malayalam]);
      expect(prefs.getString('user_language_preference'), 'ml');
      expect(await service.getSelectedLanguage(), AppLanguage.malayalam);
      await sub.cancel();
    });

    test('a DB null never overwrites the local language', () async {
      await build(localLanguage: 'hi');
      await service.getSelectedLanguage();
      serverRequests.single.complete(const Right(null));
      await settle();

      expect(await service.getSelectedLanguage(), AppLanguage.hindi);
      expect(prefs.getString('user_language_preference'), 'hi');
    });

    test('waits for the server only when nothing is stored locally', () async {
      await build();

      final pending = service.getSelectedLanguage();
      serverRequests.single.complete(const Right(AppLanguage.hindi));

      expect(await pending, AppLanguage.hindi);
    });

    test('signed out: local only, no server request', () async {
      await build(localLanguage: 'ml', userId: null);

      expect(await service.getSelectedLanguage(), AppLanguage.malayalam);
      expect(serverRequests, isEmpty);
    });
  });

  group('invalidation', () {
    test(
        'a language change is served immediately and beats a response in flight',
        () async {
      await build(localLanguage: 'en');
      await service.getSelectedLanguage(); // starts the reconcile

      await service.saveLanguagePreference(AppLanguage.hindi);
      expect(await service.getSelectedLanguage(), AppLanguage.hindi);

      // The response that started before the change arrives late.
      serverRequests.first.complete(const Right(AppLanguage.malayalam));
      await settle();

      expect(await service.getSelectedLanguage(), AppLanguage.hindi);
      expect(prefs.getString('user_language_preference'), 'hi');
      expect(serverRequests, hasLength(1),
          reason: 'the saved language is fresh; no new request');
    });

    test('logout drops the cache so the next read goes back to the server',
        () async {
      await build(localLanguage: 'en');
      await service.getSelectedLanguage();
      serverRequests.single.complete(const Right(AppLanguage.english));
      await settle();

      service.invalidateLanguageCache();
      await service.getSelectedLanguage();

      expect(serverRequests, hasLength(2));
    });

    test('a response in flight at logout is discarded', () async {
      await build(localLanguage: 'en');
      await service.getSelectedLanguage();

      service.invalidateLanguageCache();
      serverRequests.single.complete(const Right(AppLanguage.malayalam));
      await settle();

      expect(prefs.getString('user_language_preference'), 'en');
    });

    test('a user switch refetches and ignores the previous user response',
        () async {
      await build(localLanguage: 'en');
      await service.getSelectedLanguage();
      serverRequests.single.complete(const Right(AppLanguage.english));
      await settle();

      // Same process, different account.
      when(authState.userId).thenReturn('user-b');
      await service.getSelectedLanguage();
      expect(serverRequests, hasLength(2), reason: 'cache not shared');

      when(authState.userId).thenReturn('user-c');
      await service.getSelectedLanguage();
      // user-b's answer lands after the switch to user-c.
      serverRequests[1].complete(const Right(AppLanguage.malayalam));
      await settle();

      expect(prefs.getString('user_language_preference'), 'en');
      expect(serverRequests, hasLength(3));
    });
  });

  group('LocaleService.initialize', () {
    test('uses the local language and makes no network call', () async {
      await build(localLanguage: 'ml');
      final localeService = LocaleService(languagePreferenceService: service);

      await localeService.initialize();

      expect(localeService.currentLocale.languageCode, 'ml');
      expect(serverRequests, isEmpty);
      localeService.dispose();
    });

    test('follows a later server reconcile', () async {
      await build(localLanguage: 'en');
      final localeService = LocaleService(languagePreferenceService: service);
      await localeService.initialize();

      await service.getSelectedLanguage();
      serverRequests.single.complete(const Right(AppLanguage.hindi));
      await settle();

      expect(localeService.currentLocale.languageCode, 'hi');
      localeService.dispose();
    });
  });
}
