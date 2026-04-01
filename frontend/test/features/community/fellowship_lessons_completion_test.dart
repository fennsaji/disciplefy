// frontend/test/features/community/fellowship_lessons_completion_test.dart
//
// TDD red-phase test: verifies that when a mentor completes the final guide
// in a fellowship learning path, an AlertDialog with "Path Complete!" appears.
// This test is expected to FAIL until the dialog is implemented in
// FellowshipLessonsTabScreen.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_lessons_tab_screen.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_paths_cache_service.dart';

import 'fellowship_lessons_completion_test.mocks.dart';

@GenerateMocks([
  FellowshipStudyBloc,
  FellowshipMembersBloc,
  FellowshipFeedBloc,
  LearningPathsBloc,
  LanguagePreferenceService,
  LearningPathsRepository,
  LearningPathsCacheService,
])
void main() {
  late MockFellowshipStudyBloc mockStudyBloc;
  late MockFellowshipMembersBloc mockMembersBloc;
  late MockFellowshipFeedBloc mockFeedBloc;
  late MockLearningPathsBloc mockPathsBloc;
  late MockLanguagePreferenceService mockLangService;
  late MockLearningPathsRepository mockPathsRepo;
  late MockLearningPathsCacheService mockCacheService;
  late Directory tempDir;

  // Baseline idle state — mentor, path assigned, not yet completed.
  FellowshipStudyState idleState() => const FellowshipStudyState(
        fellowshipId: 'f1',
        isMentor: true,
        currentLearningPathId: 'path1',
        currentPathTitle: 'Romans Foundations',
      );

  // State emitted after the final advance succeeds.
  FellowshipStudyState completedState() => const FellowshipStudyState(
        fellowshipId: 'f1',
        isMentor: true,
        currentLearningPathId: 'path1',
        currentPathTitle: 'Romans Foundations',
        advanceStatus: FellowshipStudyAdvanceStatus.success,
        studyCompleted: true,
      );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_completion_test');
    Hive.init(tempDir.path);
    await Hive.openBox('app_settings');
  });

  setUp(() {
    // Reset DI container so each test gets fresh mock instances.
    sl.reset();

    mockStudyBloc = MockFellowshipStudyBloc();
    mockMembersBloc = MockFellowshipMembersBloc();
    mockFeedBloc = MockFellowshipFeedBloc();
    mockPathsBloc = MockLearningPathsBloc();
    mockLangService = MockLanguagePreferenceService();
    mockPathsRepo = MockLearningPathsRepository();
    mockCacheService = MockLearningPathsCacheService();

    // LanguagePreferenceService: return English by default.
    when(mockLangService.getStudyContentLanguage())
        .thenAnswer((_) async => AppLanguage.english);

    // Members bloc: mentor confirmed, no members loaded yet.
    when(mockMembersBloc.state).thenReturn(
      const FellowshipMembersState(),
    );
    when(mockMembersBloc.stream).thenAnswer(
      (_) => Stream.value(
        const FellowshipMembersState(),
      ),
    );

    // Feed bloc: empty.
    when(mockFeedBloc.state).thenReturn(const FellowshipFeedState());
    when(mockFeedBloc.stream)
        .thenAnswer((_) => Stream.value(const FellowshipFeedState()));

    // Paths bloc: no path loaded.
    when(mockPathsBloc.state).thenReturn(const LearningPathsInitial());
    when(mockPathsBloc.stream)
        .thenAnswer((_) => Stream.value(const LearningPathsInitial()));

    // Register required singletons.
    sl.registerLazySingleton<LanguagePreferenceService>(() => mockLangService);
    sl.registerLazySingleton<LearningPathsRepository>(() => mockPathsRepo);
    sl.registerLazySingleton<LearningPathsCacheService>(() => mockCacheService);
    sl.registerFactory<LearningPathsBloc>(() => mockPathsBloc);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
    sl.reset();
  });

  Widget buildTestWidget() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FellowshipStudyBloc>.value(value: mockStudyBloc),
        BlocProvider<FellowshipMembersBloc>.value(value: mockMembersBloc),
        BlocProvider<FellowshipFeedBloc>.value(value: mockFeedBloc),
        BlocProvider<LearningPathsBloc>.value(value: mockPathsBloc),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor),
        ),
        home: const Scaffold(
          body: FellowshipLessonsTabScreen(fellowshipId: 'f1'),
        ),
      ),
    );
  }

  group('Path completion dialog', () {
    testWidgets('shows "Path Complete!" dialog when mentor completes path',
        (tester) async {
      // Arrange: start idle, then emit completed.
      when(mockStudyBloc.state).thenReturn(idleState());
      when(mockStudyBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([idleState(), completedState()]),
      );

      // Act
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(); // process stream emission
      await tester.pump(); // settle animations

      // Assert
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Path Complete!'), findsOneWidget);
      expect(find.text('Romans Foundations'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Choose Next Path'), findsOneWidget);
    });

    testWidgets('"Later" dismisses the dialog', (tester) async {
      when(mockStudyBloc.state).thenReturn(idleState());
      when(mockStudyBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([idleState(), completedState()]),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('does NOT show dialog for non-mentor members', (tester) async {
      const nonMentorIdle = FellowshipStudyState(
        fellowshipId: 'f1',
        currentLearningPathId: 'path1',
        currentPathTitle: 'Romans Foundations',
      );
      const nonMentorCompleted = FellowshipStudyState(
        fellowshipId: 'f1',
        currentLearningPathId: 'path1',
        currentPathTitle: 'Romans Foundations',
        advanceStatus: FellowshipStudyAdvanceStatus.success,
        studyCompleted: true,
      );

      when(mockStudyBloc.state).thenReturn(nonMentorIdle);
      when(mockStudyBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([nonMentorIdle, nonMentorCompleted]),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      // Current behaviour: SnackBar fires instead of a dialog.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('does NOT show dialog for mid-path advances (not completed)',
        (tester) async {
      const midAdvance = FellowshipStudyState(
        fellowshipId: 'f1',
        isMentor: true,
        currentLearningPathId: 'path1',
        currentPathTitle: 'Romans Foundations',
        advanceStatus: FellowshipStudyAdvanceStatus.success,
        currentGuideIndex: 1,
        totalGuides: 5,
      );

      when(mockStudyBloc.state).thenReturn(idleState());
      when(mockStudyBloc.stream).thenAnswer(
        (_) => Stream.fromIterable([idleState(), midAdvance]),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
