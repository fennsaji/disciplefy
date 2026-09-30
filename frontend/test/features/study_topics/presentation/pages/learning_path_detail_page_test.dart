import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/learning_path_detail_page.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_detail_parts.dart';

import '../../../../helpers/welcome_test_harness.dart';
import '../../../settings/text_fit.dart';

class _MockPathsBloc extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _FakeDownloads extends Fake implements LearningPathDownloadService {
  _FakeDownloads([this.model]);

  /// The path's download, or null when nothing was downloaded.
  final LearningPathDownloadModel? model;
  final List<String> paused = [];

  @override
  Stream<LearningPathDownloadModel> watchDownload(String learningPathId) =>
      const Stream.empty();

  @override
  LearningPathDownloadModel? getDownload(String learningPathId) => model;

  @override
  Future<void> pauseDownload(String learningPathId) async =>
      paused.add(learningPathId);
}

/// A download in progress: two guides done, one downloading, one failed,
/// the rest waiting.
LearningPathDownloadModel _downloading() {
  LearningPathTopicDownload topic(int i, TopicDownloadStatus status) =>
      LearningPathTopicDownload(
        topicId: 't$i',
        topicTitle: 'Topic $i',
        inputType: 'topic',
        description: '',
        studyMode: 'standard',
        status: status,
        cachedGuideId: status == TopicDownloadStatus.done ? 'g$i' : null,
      );
  return LearningPathDownloadModel(
    learningPathId: 'path-1',
    learningPathTitle: 'New Believer Essentials',
    language: 'en',
    topics: [
      topic(0, TopicDownloadStatus.done),
      topic(1, TopicDownloadStatus.done),
      topic(2, TopicDownloadStatus.downloading),
      topic(3, TopicDownloadStatus.failed),
      topic(4, TopicDownloadStatus.pending),
      topic(5, TopicDownloadStatus.pending),
    ],
    status: PathDownloadStatus.downloading,
    queuedAt: DateTime(2026),
    completedCount: 2,
    totalCount: 6,
  );
}

class _FakeLanguagePrefs extends Fake implements LanguagePreferenceService {
  @override
  Future<AppLanguage> getStudyContentLanguage() async => AppLanguage.english;

  @override
  String? getLearningPathStudyModePreferenceRaw() => null;
}

LearningPathTopic _topic(int i, {bool done = false}) => LearningPathTopic(
      position: i,
      isMilestone: i == 3,
      topicId: 't$i',
      title: const [
        'Who is Jesus Christ?',
        'One God, Three Persons',
        'What is the Gospel?',
        'Confidence in Your Salvation',
        'Why Read the Bible?',
        'Importance of Prayer',
      ][i],
      description: '',
      category: 'Foundations',
      xpValue: 50,
      isCompleted: done,
    );

LearningPathDetail _path({required bool enrolled, int completed = 3}) =>
    LearningPathDetail(
      id: 'path-1',
      slug: 'new-believer',
      title: 'New Believer Essentials',
      description: 'Begin your faith journey with these foundational topics. '
          'Learn about Jesus, the Gospel, and how to grow in your walk with '
          'God through prayer, Scripture and fellowship every single day.',
      iconName: 'auto_stories',
      color: '#4F46E5',
      totalXp: 400,
      estimatedDays: 14,
      discipleLevel: 'seeker',
      recommendedMode: 'standard',
      topicsCount: 6,
      isEnrolled: enrolled,
      progressPercentage: enrolled ? 50 : 0,
      category: 'Foundations',
      topicsCompleted: enrolled ? completed : 0,
      topics: [
        for (var i = 0; i < 6; i++) _topic(i, done: enrolled && i < completed),
      ],
    );

void main() {
  late FakeTranslationService translations;
  late _MockPathsBloc bloc;
  late _MockConnectivityBloc connectivity;

  setUpAll(() {
    registerFallbackValue(const EnrollInLearningPath(pathId: 'x'));
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<LearningPathDownloadService>(_FakeDownloads());
    sl.registerSingleton<LanguagePreferenceService>(_FakeLanguagePrefs());
    bloc = _MockPathsBloc();
    connectivity = _MockConnectivityBloc();
    when(() => connectivity.state).thenReturn(ConnectivityOnline());
  });
  tearDown(() async => sl.reset());

  Future<void> pump(
    WidgetTester tester,
    LearningPathsState state, {
    bool dark = true,
    AppLanguage language = AppLanguage.english,
    Size size = const Size(320, 640),
  }) async {
    translations.language = language;
    useSurface(tester, size);
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<LearningPathsBloc>.value(value: bloc),
        BlocProvider<ConnectivityBloc>.value(value: connectivity),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(language.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LearningPathDetailPage(pathId: 'path-1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('fits 320x640', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          await pump(
            tester,
            LearningPathDetailLoaded(pathDetail: _path(enrolled: true)),
            dark: dark,
            language: language,
          );
          expect(tester.takeException(), isNull);
          // The clamped description and the CTA's topic title may ellipsize.
          expectNoTruncatedText(tester, allowed: {
            _path(enrolled: true).description,
            // Path and topic titles are content; the test font renders
            // every glyph 1em wide, so they wrap far more than real text.
            'New Believer Essentials',
            '${translations.getTranslation(TranslationKeys.learningPathsContinue)}'
                ' · Confidence in Your Salvation',
          });
          expect(find.byType(PathDetailCtaBar), findsOneWidget);
        });
      }
    }
  });

  testWidgets('enrolled: current topic highlighted and CTA continues it',
      (tester) async {
    await pump(
        tester, LearningPathDetailLoaded(pathDetail: _path(enrolled: true)),
        size: const Size(400, 1600));

    final rows = tester
        .widgetList<PathTopicRow>(
            find.byType(PathTopicRow, skipOffstage: false))
        .toList();
    expect(rows.take(3).every((r) => r.status == PathTopicStatus.completed),
        isTrue);
    expect(rows[3].status, PathTopicStatus.current);
    expect(rows[3].upNextLine, contains('8 min'));
    expect(rows[4].status, PathTopicStatus.locked);

    expect(
      find.text(
          '${translations.getTranslation(TranslationKeys.learningPathsContinue)}'
          ' · Confidence in Your Salvation'),
      findsOneWidget,
    );
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('SEEKER · FOUNDATIONS'), findsOneWidget);
  });

  testWidgets('not enrolled: CTA enrolls in the path', (tester) async {
    await pump(
        tester, LearningPathDetailLoaded(pathDetail: _path(enrolled: false)));

    final label =
        translations.getTranslation(TranslationKeys.learningPathsStartPath);
    expect(find.text(label), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('path-detail-cta')));
    verify(() => bloc.add(const EnrollInLearningPath(pathId: 'path-1')))
        .called(1);
  });

  testWidgets('description toggles between 2 lines and full text',
      (tester) async {
    await pump(
        tester, LearningPathDetailLoaded(pathDetail: _path(enrolled: true)));
    final more = translations.getTranslation(TranslationKeys.commonShowMore);
    final less = translations.getTranslation(TranslationKeys.commonShowLess);
    expect(find.text(more), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('path-description-toggle')));
    await tester.pump();
    expect(find.text(less), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    await pump(tester, const LearningPathsError(message: 'boom'));
    expect(tester.takeException(), isNull);
    await tester.tap(
        find.text(translations.getTranslation(TranslationKeys.commonRetry)));
    verify(() => bloc.add(any(that: isA<LoadLearningPathDetails>())))
        .called(greaterThanOrEqualTo(1));
  });

  testWidgets('topic rows: locked rows ignore taps', (tester) async {
    var taps = 0;
    useSurface(tester, const Size(320, 640));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Column(children: [
          PathTopicRow(
            number: 1,
            title: 'Open',
            category: 'c',
            xp: 10,
            status: PathTopicStatus.upcoming,
            onTap: () => taps++,
          ),
          PathTopicRow(
            number: 2,
            title: 'Locked',
            category: 'c',
            xp: 10,
            status: PathTopicStatus.locked,
            onTap: () => taps++,
          ),
        ]),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.tap(find.text('Locked'));
    expect(taps, 1);
  });

  group('offline download sheet', () {
    late _FakeDownloads downloads;

    setUp(() {
      downloads = _FakeDownloads(_downloading());
      sl
        ..unregister<LearningPathDownloadService>()
        ..registerSingleton<LearningPathDownloadService>(downloads);
    });

    Future<void> openSheet(WidgetTester tester,
        {required bool dark, required AppLanguage language}) async {
      await pump(
        tester,
        LearningPathDetailLoaded(pathDetail: _path(enrolled: true)),
        dark: dark,
        language: language,
      );
      await tester.tap(find.byTooltip(translations
          .getTranslation(TranslationKeys.downloadsStatusDownloading)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('fits 320x640 ${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          await openSheet(tester, dark: dark, language: language);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester, allowed: {
            // The page behind the sheet: its clamped description and CTA.
            _path(enrolled: true).description,
            '${translations.getTranslation(TranslationKeys.learningPathsContinue)}'
                ' · Confidence in Your Salvation',
            // Content titles; the test font renders every glyph 1em wide.
            'New Believer Essentials',
            'NEW BELIEVER ESSENTIALS',
          });
          expect(find.byKey(const Key('download_sheet_pause')), findsOneWidget);
          expect(
              find.byKey(const Key('download_sheet_cancel')), findsOneWidget);
        });
      }
    }

    testWidgets('pause still pauses the download', (tester) async {
      await openSheet(tester, dark: true, language: AppLanguage.english);
      await tester.tap(find.byKey(const Key('download_sheet_pause')));
      await tester.pump();
      expect(downloads.paused, ['path-1']);
    });
  });
}
