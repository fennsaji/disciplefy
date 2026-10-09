import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

import '../services/content_language_independence_test.mocks.dart';

/// The saved "Default study mode" reaches new studies that name no mode,
/// and the learning-path mode is readable on a lesson card's first frame.
void main() {
  late MockAuthStateProvider authState;

  Future<LanguagePreferenceService> build({
    Map<String, Object> local = const {},
    Map<String, dynamic>? profile,
    bool signedIn = true,
  }) async {
    SharedPreferences.setMockInitialValues(local);
    final prefs = await SharedPreferences.getInstance();
    authState = MockAuthStateProvider();
    when(authState.isAuthenticated).thenReturn(signedIn);
    when(authState.userId).thenReturn(signedIn ? 'u1' : null);
    when(authState.userProfile).thenReturn(profile);
    final service = LanguagePreferenceService(
      prefs: prefs,
      authService: MockAuthService(),
      authStateProvider: authState,
      userProfileService: MockUserProfileService(),
      cacheCoordinator: MockLanguageCacheCoordinator(),
    );
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<LanguagePreferenceService>(service);
    return service;
  }

  tearDown(() => GetIt.instance.reset());

  group('peekStudyModePreferenceRaw', () {
    test('reads the loaded profile first', () async {
      final service = await build(
        local: {'user_study_mode_preference': 'quick'},
        profile: {'default_study_mode': 'deep'},
      );
      expect(service.peekStudyModePreferenceRaw(), 'deep');
    });

    test('a loaded profile with no mode means no preference', () async {
      final service = await build(
        local: {'user_study_mode_preference': 'quick'},
        profile: {'default_study_mode': null},
      );
      expect(service.peekStudyModePreferenceRaw(), isNull);
    });

    test('falls back to this device before the profile loads', () async {
      final service =
          await build(local: {'user_study_mode_preference': 'lectio'});
      expect(service.peekStudyModePreferenceRaw(), 'lectio');
    });

    test('a guest reads this device', () async {
      final service = await build(
          local: {'user_study_mode_preference': 'quick'}, signedIn: false);
      expect(service.peekStudyModePreferenceRaw(), 'quick');
    });
  });

  group('savedStudyModeOr', () {
    for (final entry in {
      'quick': StudyMode.quick,
      'standard': StudyMode.standard,
      'deep': StudyMode.deep,
      'sermon': StudyMode.sermon,
    }.entries) {
      test('a saved ${entry.key} wins', () async {
        await build(profile: {'default_study_mode': entry.key});
        expect(savedStudyModeOr(StudyMode.standard), entry.value);
      });
    }

    for (final raw in [null, 'recommended', 'ask']) {
      test('"$raw" uses the fallback', () async {
        await build(profile: {'default_study_mode': raw});
        expect(savedStudyModeOr(StudyMode.standard), StudyMode.standard);
        expect(savedStudyModeOr(StudyMode.quick), StudyMode.quick);
      });
    }

    test('no service registered uses the fallback', () async {
      await GetIt.instance.reset();
      expect(savedStudyModeOr(StudyMode.standard), StudyMode.standard);
    });
  });

  group('studyModeForLink', () {
    test('a named mode wins over the preference', () async {
      await build(profile: {'default_study_mode': 'deep'});
      expect(studyModeForLink('quick', isLesson: false), StudyMode.quick);
    });

    test('no mode: the saved default (notification, tapped verse)', () async {
      await build(profile: {'default_study_mode': 'deep'});
      expect(studyModeForLink(null, isLesson: false), StudyMode.deep);
    });

    test('no mode and no concrete preference: Standard', () async {
      await build(profile: {'default_study_mode': 'recommended'});
      expect(studyModeForLink(null, isLesson: false), StudyMode.standard);
    });

    test('a lesson without a mode stays Standard', () async {
      await build(profile: {'default_study_mode': 'deep'});
      expect(studyModeForLink(null, isLesson: true), StudyMode.standard);
    });
  });

  group('nextLessonModeNow', () {
    test('the saved learning-path mode, read synchronously', () async {
      await build(profile: {'learning_path_study_mode': 'quick'});
      expect(nextLessonModeNow(), StudyMode.quick);
    });

    test('"recommended" and "ask" mean Standard', () async {
      await build(profile: {'learning_path_study_mode': 'recommended'});
      expect(nextLessonModeNow(), StudyMode.standard);
      await build(profile: {'learning_path_study_mode': 'ask'});
      expect(nextLessonModeNow(), StudyMode.standard);
    });
  });
}
