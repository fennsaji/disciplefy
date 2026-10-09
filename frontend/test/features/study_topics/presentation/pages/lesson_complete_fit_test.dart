import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
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

class _FakePrefs extends Fake implements LanguagePreferenceService {
  @override
  String? getLearningPathStudyModePreferenceRaw() => 'recommended';
}

/// Real lesson titles of New Believer Essentials, as the backend returns them.
const _titles = {
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

  Future<void> pumpPage(WidgetTester tester, FitCase c, int n) async {
    final repo = _MockRepo();
    when(() => repo.getLearningPathDetails(
          pathId: any(named: 'pathId'),
          language: any(named: 'language'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => Right(_path(c.lang)));
    sl.registerSingleton<LearningPathsRepository>(repo);
    useFitSurface(tester, c);
    await tester.pumpWidget(welcomeApp(
      language: c.lang,
      dark: c.dark,
      path: '/lesson-complete',
      screen: LessonCompletePage(
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
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final c in fitCases()) {
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

    testWidgets('${c.name}: last lesson fits', (tester) async {
      await pumpPage(tester, c, 8);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester, allow: {..._titles[c.lang]!});
    });
  }
}
