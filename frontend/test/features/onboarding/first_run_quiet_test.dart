import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/first_run_flags.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockPaths extends Mock implements LearningPathsRepository {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockLanguage extends Mock implements LanguagePreferenceService {}

class _MockWalkthrough extends Mock implements WalkthroughRepository {}

User _user({required bool anon}) => User(
      id: 'u1',
      appMetadata: const {'provider': 'email'},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      isAnonymous: anon,
    );

void main() {
  late Directory tempDir;
  late Box settings;

  setUpAll(() async {
    registerFallbackValue(AppLanguage.english);
    registerFallbackValue(WalkthroughScreen.home);
    tempDir = await Directory.systemTemp.createTemp('first_run_quiet_test');
    Hive.init(tempDir.path);
    settings = await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() => settings.clear());

  group('FirstRunCubit tours', () {
    late _MockWalkthrough walkthrough;
    late _MockPaths paths;
    late _MockGuest guest;

    FirstRunCubit cubit() {
      final flags = _MockFlags();
      when(() => flags.guestMode).thenReturn(true);
      final language = _MockLanguage();
      when(() => language.saveLanguagePreference(any()))
          .thenAnswer((_) async {});
      return FirstRunCubit(
        guest: guest,
        paths: paths,
        flags: flags,
        language: language,
        settings: settings,
        walkthrough: walkthrough,
      );
    }

    setUp(() {
      walkthrough = _MockWalkthrough();
      paths = _MockPaths();
      guest = _MockGuest();
      when(() => walkthrough.markSeen(any())).thenAnswer((_) async {});
      when(() => guest.hasSession).thenReturn(true);
      when(() => guest.isGuest).thenReturn(true);
      when(() => paths.enrollInPathBySlug(any())).thenAnswer((_) async => Right(
          EnrollmentResult(
              id: 'e',
              learningPathId: 'p1',
              enrolledAt: DateTime(2026),
              startedAt: DateTime(2026))));
      when(() => paths.getLearningPathDetails(
            pathId: 'p1',
            language: any(named: 'language'),
            forceRefresh: true,
          )).thenAnswer((_) async => Right(LearningPathDetail.forTest(
            id: 'p1',
            title: 'Path',
            description: '',
            topics: [
              LearningPathTopic(
                position: 1,
                isMilestone: false,
                topicId: 't1',
                title: 'L1',
                description: '',
                category: 'c',
                xpValue: 10,
              ),
            ],
          )));
    });

    blocTest<FirstRunCubit, FirstRunState>(
      'marks all tours seen when lesson 1 opens',
      build: cubit,
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunReady>()],
      verify: (_) {
        for (final s in WalkthroughScreen.values) {
          verify(() => walkthrough.markSeen(s)).called(1);
        }
      },
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'marks no tour seen when lesson 1 fails to open',
      setUp: () => when(() => paths.enrollInPathBySlug(any()))
          .thenAnswer((_) async => Left(const ServerFailure())),
      build: cubit,
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunFailed>()],
      verify: (_) => verifyNever(() => walkthrough.markSeen(any())),
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'a tour that cannot be saved does not block lesson 1',
      setUp: () => when(() => walkthrough.markSeen(any()))
          .thenThrow(StateError('hive closed')),
      build: cubit,
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunReady>()],
    );
  });

  group('FirstRunFlags prompts', () {
    test('existing user (no goal, no flag) still gets prompts', () {
      expect(FirstRunFlags.notificationPromptsAllowed, isTrue);
    });

    test('new first-run user waits for lesson 1', () async {
      await settings.put('first_run_goal', 'newToFaith');
      expect(FirstRunFlags.notificationPromptsAllowed, isFalse);
    });

    test('first-run user gets prompts after lesson 1', () async {
      await settings.put('first_run_goal', 'newToFaith');
      await FirstRunFlags.markFirstLessonCompleted();
      expect(settings.get('first_lesson_completed'), isTrue);
      expect(FirstRunFlags.notificationPromptsAllowed, isTrue);
    });
  });

  group('needsEmailVerification', () {
    test('anonymous user never needs email verification', () {
      final s = AuthenticatedState(user: _user(anon: true));
      expect(s.needsEmailVerification, isFalse);
    });

    test('email user without a verified flag still does', () {
      final s = AuthenticatedState(user: _user(anon: false));
      expect(s.needsEmailVerification, isTrue);
    });
  });
}
