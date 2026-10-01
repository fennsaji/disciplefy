import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:disciplefy_bible_study/features/feedback/presentation/widgets/feedback_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_event.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_state.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/pages/bible_attribution_screen.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/pages/offline_guides_screen.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/pages/settings_screen.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheets.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';

import '../../helpers/welcome_test_harness.dart';
import 'text_fit.dart';

class _MockFeedbackBloc extends MockBloc<FeedbackEvent, FeedbackState>
    implements FeedbackBloc {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _FakeDownloads extends Fake implements LearningPathDownloadService {
  List<LearningPathDownloadModel> paths;
  final List<String> deleted = [];

  _FakeDownloads(this.paths);

  @override
  Future<List<LearningPathDownloadModel>> getAllDownloads() async => paths;

  @override
  Future<void> deleteDownload(String learningPathId) async {
    deleted.add(learningPathId);
    paths = paths.where((p) => p.learningPathId != learningPathId).toList();
  }
}

class _FakeLocalGuides extends Fake implements StudyLocalDataSource {
  @override
  Future<List<StudyGuide>> getCachedStudyGuides() async => [];
}

LearningPathDownloadModel _path() => LearningPathDownloadModel(
      learningPathId: 'p1',
      learningPathTitle: 'New Believer Essentials',
      language: 'en',
      status: PathDownloadStatus.completed,
      queuedAt: DateTime(2026),
      completedCount: 2,
      totalCount: 2,
      topics: const [
        LearningPathTopicDownload(
          topicId: 't1',
          topicTitle: 'Who is Jesus Christ?',
          inputType: 'topic',
          description: '',
          studyMode: 'standard',
          status: TopicDownloadStatus.done,
          cachedGuideId: 'g1',
        ),
        LearningPathTopicDownload(
          topicId: 't2',
          topicTitle: 'One God, Three Persons',
          inputType: 'topic',
          description: '',
          studyMode: 'standard',
          status: TopicDownloadStatus.done,
          cachedGuideId: 'g2',
        ),
      ],
    );

void main() {
  late FakeTranslationService translations;

  setUpAll(() => registerFallbackValue(const ResetFeedbackState()));

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

  Widget app(Widget screen, {required bool dark}) {
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => screen),
        GoRoute(path: '/', builder: (_, __) => const Text('stub:/')),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  group('OfflineGuidesScreen', () {
    late _FakeDownloads downloads;

    setUp(() {
      downloads = _FakeDownloads([_path()]);
      sl.registerSingleton<LearningPathDownloadService>(downloads);
      sl.registerSingleton<StudyLocalDataSource>(_FakeLocalGuides());
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: storage card and guide rows',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const OfflineGuidesScreen(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Offline guides'), findsOneWidget);
        expect(find.text('Read without internet'), findsOneWidget);
        expect(find.text('2 guides'), findsOneWidget);
        expect(find.text('NEW BELIEVER ESSENTIALS'), findsOneWidget);
        expect(find.text('Who is Jesus Christ?'), findsOneWidget);
        expect(find.text('Remove'), findsNWidgets(2));
      });
    }

    testWidgets('Clear all confirms, then deletes every path', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const OfflineGuidesScreen(), dark: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Remove all offline guides?'), findsOneWidget);
      await tester.tap(find.text('Clear all').last);
      await tester.pumpAndSettle();

      expect(downloads.deleted, ['p1']);
      expect(find.text('No offline guides downloaded yet'), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const OfflineGuidesScreen(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BibleAttributionScreen', () {
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: versions, notices and sources',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester
            .pumpWidget(app(const BibleAttributionScreen(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('English · BSB'), findsOneWidget);
        expect(find.text('English · KJV'), findsOneWidget);
        // Native-script language names are shown again.
        expect(find.text('हिन्दी (Hindi) · IRV'), findsOneWidget);
        expect(find.text('മലയാളം (Malayalam) · IRV'), findsOneWidget);
        expect(find.textContaining('Public domain'), findsNWidgets(2));
        await tester.scrollUntilVisible(find.text('eBible.org'), 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.text('മലയാളം (Malayalam) · SV 1910'), findsOneWidget);
        expect(find.text('CC BY-SA 4.0'), findsNWidgets(3));
        expect(find.textContaining('Bridge Connectivity Solutions'),
            findsNWidgets(2));
        expect(find.textContaining('API.Bible'), findsNothing);
        expect(find.text('eBible.org'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Feedback sheet', () {
    late _MockFeedbackBloc bloc;

    setUp(() {
      bloc = _MockFeedbackBloc();
      whenListen(bloc, const Stream<FeedbackState>.empty(),
          initialState: const FeedbackInitial());
    });

    Widget sheet(bool dark) => app(
          Scaffold(
            body: BlocProvider<FeedbackBloc>.value(
              value: bloc,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: FeedbackBottomSheet(),
              ),
            ),
          ),
          dark: dark,
        );

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: helpful toggle, chips, send',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(sheet(dark));
        await tester.pumpAndSettle();

        expect(find.text('Is the app helpful?'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('Not yet'), findsOneWidget);
        expect(find.text('TOPIC'), findsOneWidget);
        expect(find.text('Bug Report'), findsOneWidget);
        expect(find.text('Send Feedback'), findsNWidgets(2)); // title + button

        await tester.tap(find.text('Not yet'));
        await tester.tap(find.text('Bug Report'));
        await tester.pump();
        // Empty message: validation snackbar, no event.
        await tester.tap(find.text('Send Feedback').last);
        await tester.pump();
        expect(find.text('Please enter a message'), findsOneWidget);
        verifyNever(() => bloc.add(any()));
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(sheet(true));
        await tester.pumpAndSettle();
        expectNoTruncatedText(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('App language sheet', () {
    testWidgets('picking Hindi dispatches UpdateLanguage(hi)', (tester) async {
      final bloc = _MockSettingsBloc();
      whenListen(bloc, const Stream<SettingsState>.empty(),
          initialState: SettingsInitial());
      useSurface(tester, const Size(320, 640));
      await tester.pumpWidget(BlocProvider<SettingsBloc>.value(
        value: bloc,
        child: app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppLanguageSheet(context, 'en'),
                child: const Text('open'),
              ),
            ),
          ),
          dark: true,
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const UpdateLanguage('hi'))).called(1);
    });
  });

  group('Delete account warning', () {
    for (final language in AppLanguage.values) {
      testWidgets('320 ${language.code}: lists losses without overflow',
          (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: DeleteAccountWarningBox(
                title: 'You will permanently lose',
                items: [
                  'Your study guides and notes',
                  'Your memory verses and streaks',
                  'Your XP, level and achievements',
                  'Any active plan (cancel your subscription first)',
                ],
              ),
            ),
          ),
          dark: language != AppLanguage.english,
        ));
        await tester.pumpAndSettle();
        expect(find.text('You will permanently lose'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
