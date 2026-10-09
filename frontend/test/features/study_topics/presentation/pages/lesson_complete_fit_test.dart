import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/guest_lesson_nudge.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/utils/achievement_popup_gate.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/lesson_complete_page.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

class _MockRepo extends Mock implements LearningPathsRepository {}

class _MockGuest extends Mock implements GuestSessionService {}

class _FakePrefs extends Fake implements LanguagePreferenceService {
  @override
  String? getLearningPathStudyModePreferenceRaw() => 'recommended';
}

/// Real lesson titles of New Believer Essentials, as the backend returns them.
const _titles = {
  'en': [
    'Who Is Jesus Christ?',
    'One God, Three Persons',
    'Why Read the Bible?',
    'Assurance of Your Salvation',
    'How to Pray',
    'The Importance of the Church',
    "Baptism and the Lord's Supper",
    'Sharing Your Faith',
  ],
  'hi': [
    'यीशु मसीह कौन हैं?',
    'एक परमेश्वर, तीन व्यक्ति',
    'बाइबल क्यों पढ़ें?',
    'अपने उद्धार में विश्वास',
    'प्रार्थना कैसे करें',
    'कलीसिया का महत्व',
    'बपतिस्मा और प्रभु भोज',
    'अपना विश्वास बाँटना',
  ],
  'ml': [
    'യേശുക്രിസ്തു ആരാണ്?',
    'ഏക ദൈവം, മൂന്ന് വ്യക്തികൾ',
    'എന്തുകൊണ്ട് ബൈബിൾ വായിക്കണം?',
    'നിങ്ങളുടെ രക്ഷയിലുള്ള വിശ്വാസം',
    'എങ്ങനെ പ്രാർത്ഥിക്കാം',
    'സഭയുടെ പ്രാധാന്യം',
    'സ്നാനവും തിരുവത്താഴവും',
    'നിങ്ങളുടെ വിശ്വാസം പങ്കുവെക്കൽ',
  ],
};

const _pathTitle = {
  'en': 'New Believer Essentials',
  'hi': 'विश्वास की नींव',
  'ml': 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ',
};

LearningPathDetail _path(String lang) => LearningPathDetail(
      id: 'p',
      slug: 'new-believer-essentials',
      title: _pathTitle[lang]!,
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      topicsCount: 8,
      topics: [
        for (var i = 0; i < 8; i++)
          LearningPathTopic(
            position: i + 1,
            isMilestone: false,
            topicId: 't${i + 1}',
            title: _titles[lang]![i],
            description: '',
            category: 'c',
            xpValue: 50,
          ),
      ],
    );

/// Lesson complete at 360px and 320px in Hindi and Malayalam, light and dark:
/// the mid-path page (Up next + two buttons) and the last-lesson page.
void main() {
  setUpAll(loadAppFonts);

  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<LanguagePreferenceService>(_FakePrefs());
  });
  tearDown(() {
    AchievementPopupGate.reset();
    return sl.reset();
  });

  Future<void> pumpPage(WidgetTester tester, FitCase c, int n,
      {bool guest = false, double height = 780, double textScale = 1}) async {
    final repo = _MockRepo();
    when(() => repo.getLearningPathDetails(
          pathId: any(named: 'pathId'),
          language: any(named: 'language'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => Right(_path(c.lang)));
    sl.registerSingleton<LearningPathsRepository>(repo);
    if (guest) {
      final session = _MockGuest();
      when(() => session.isGuest).thenReturn(true);
      sl.registerSingleton<GuestSessionService>(session);
    }
    useFitSurface(tester, c, height: height);
    await tester.pumpWidget(welcomeApp(
      language: c.lang,
      dark: c.dark,
      path: '/lesson-complete',
      screen: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: LessonCompletePage(
            args: LessonCompleteArgs(
              lesson: LessonRef(
                pathId: 'p',
                pathTitle: _pathTitle[c.lang]!,
                lessonNumber: n,
                lessonTotal: 8,
              ),
              lessonTitle: _titles[c.lang]![n - 1],
              mode: StudyMode.quick,
              language: c.lang,
            ),
            extraSections: [
              GuestLessonNudge(
                pathId: 'p',
                lessonNumber: n,
                isLastLesson: n == 8,
                firstRun: false,
                language: c.lang,
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final c in fitCases(languages: const ['en', 'hi', 'ml'])) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('${c.name} ${scale}x: bottom button labels are never cut',
          (tester) async {
        sl.allowReassignment = true;
        addTearDown(() => sl.allowReassignment = false);
        for (final n in const [4, 8]) {
          await tester.pumpWidget(const SizedBox());
          await pumpPage(tester, c, n, height: 640, textScale: scale);
          expect(tester.takeException(), isNull);
          final screen = tester.view.physicalSize.height;
          for (final b in [
            ...tester.widgetList(find.byType(FilledButton)),
            ...tester.widgetList(find.byType(OutlinedButton)),
          ]) {
            expect(tester.getRect(find.byWidget(b)).bottom,
                lessThanOrEqualTo(screen));
          }
          expectNoTruncatedText(tester, allow: {..._titles[c.lang]!});
        }
      });
    }

    testWidgets('${c.name}: lesson 4 complete fits', (tester) async {
      await pumpPage(tester, c, 4);
      expect(
          find.text(
              translations.getTranslation('lesson.complete_title', {'n': 4})),
          findsOneWidget);
      expect(find.textContaining('lesson.'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Lesson titles may clamp at two lines by design.
      expectNoTruncatedText(tester, allow: {..._titles[c.lang]!});
    });

    testWidgets('${c.name}: guest lesson 2 card fits at 640 and 1.3x',
        (tester) async {
      await pumpPage(tester, c, 2, guest: true, height: 640, textScale: 1.3);
      final card = find.byKey(const Key('keep_progress_card'));
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      // Continue / Back home stay on screen below the scrolling content.
      final screen = tester.view.physicalSize.height;
      expect(tester.getRect(find.byType(FilledButton)).bottom,
          lessThanOrEqualTo(screen));
      expect(tester.getRect(find.byType(OutlinedButton)).bottom,
          lessThanOrEqualTo(screen));
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester, allow: {..._titles[c.lang]!});
    });

    testWidgets('${c.name}: last lesson fits', (tester) async {
      await pumpPage(tester, c, 8);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester, allow: {..._titles[c.lang]!});
    });
  }
}
