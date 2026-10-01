// Regression: a slow member-language lookup must not overwrite the group
// language that arrives later, or a Hindi group shows English lessons.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_lessons_tab_screen.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';

import '../../helpers/welcome_test_harness.dart';

class _MockFeedBloc extends MockBloc<FellowshipFeedEvent, FellowshipFeedState>
    implements FellowshipFeedBloc {}

class _MockMembersBloc
    extends MockBloc<FellowshipMembersEvent, FellowshipMembersState>
    implements FellowshipMembersBloc {}

class _MockStudyBloc
    extends MockBloc<FellowshipStudyEvent, FellowshipStudyState>
    implements FellowshipStudyBloc {}

class _MockPathsBloc extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _MockLanguagePrefs extends Mock implements LanguagePreferenceService {}

void main() {
  late _MockStudyBloc study;
  late _MockPathsBloc paths;
  late Completer<AppLanguage> memberLanguage;

  setUpAll(() {
    registerFallbackValue(const LoadLearningPathDetails(pathId: ''));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.registerSingleton<SharedPreferences>(
        await SharedPreferences.getInstance());
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    final prefs = _MockLanguagePrefs();
    when(prefs.getStudyContentLanguage)
        .thenAnswer((_) => memberLanguage.future);
    sl.registerSingleton<LanguagePreferenceService>(prefs);
    study = _MockStudyBloc();
    paths = _MockPathsBloc();
    when(() => study.state).thenReturn(const FellowshipStudyState(
        fellowshipId: 'f1', currentLearningPathId: 'path1'));
    when(() => paths.state).thenReturn(const LearningPathsInitial());
  });

  tearDown(() async => sl.reset());

  Widget app(String? override) {
    final feed = _MockFeedBloc();
    when(() => feed.state).thenReturn(const FellowshipFeedState());
    final members = _MockMembersBloc();
    when(() => members.state).thenReturn(const FellowshipMembersState());
    return MultiBlocProvider(
      providers: [
        BlocProvider<FellowshipFeedBloc>.value(value: feed),
        BlocProvider<FellowshipMembersBloc>.value(value: members),
        BlocProvider<FellowshipStudyBloc>.value(value: study),
        BlocProvider<LearningPathsBloc>.value(value: paths),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FellowshipLessonsTabScreen(
            fellowshipId: 'f1',
            languageOverride: override,
            fellowshipLanguageLoader: (_) async => null,
          ),
        ),
      ),
    );
  }

  testWidgets('group language arriving late wins over slow member language',
      (tester) async {
    // Created inside the test zone so completing it is seen by pump().
    memberLanguage = Completer<AppLanguage>();
    await tester.pumpWidget(app(null));
    await tester.pump();

    // Group language delivered while the member lookup is still pending.
    await tester.pumpWidget(app('hi'));
    await tester.pump();

    memberLanguage.complete(AppLanguage.english);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final languages = verify(() => paths.add(captureAny()))
        .captured
        .whereType<LoadLearningPathDetails>()
        .map((e) => e.language)
        .toList();
    expect(languages, isNotEmpty);
    expect(languages.last, 'hi');
    expect(languages, isNot(contains('en')));
  });
}
