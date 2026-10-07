import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/depth_mode_cards.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/generate_hero.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/mode_selection_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/recent_guides_section.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/user_subscription_status.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/repositories/subscription_repository.dart';

import '../../helpers/text_fit.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  final AppLanguage language;
  _FakeLanguageService(this.language);

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => language;
}

/// Costs as the backend would return them; never hardcoded in the UI.
const _costs = {
  StudyMode.quick: 10,
  StudyMode.standard: 20,
  StudyMode.deep: 30,
  StudyMode.lectio: 20,
  StudyMode.sermon: 40,
};

class _FakeTokenCosts extends Fake implements TokenCostRepository {
  @override
  Future<Either<Failure, int>> getTokenCost(
          String language, String mode) async =>
      Right(_costs[studyModeFromString(mode)]!);
}

class _FakeSystemConfig extends Fake implements SystemConfigService {
  final Set<String> lockedKeys;
  _FakeSystemConfig({this.lockedKeys = const {}});

  @override
  bool shouldHideFeature(String featureKey, String planType) => false;

  @override
  bool isFeatureLocked(String featureKey, String planType) =>
      lockedKeys.contains(featureKey);
}

class _FakeSubscriptions extends Fake implements SubscriptionRepository {
  @override
  Future<Either<Failure, UserSubscriptionStatus>>
      getSubscriptionStatus() async => const Left(ServerFailure());
}

Future<void> _registerServices({
  AppLanguage language = AppLanguage.english,
  Set<String> lockedKeys = const {},
}) async {
  SharedPreferences.setMockInitialValues(
      {'user_language_preference': language.code});
  final prefs = await SharedPreferences.getInstance();
  await GetIt.instance.reset();
  GetIt.instance
    ..registerSingleton<TranslationService>(
        TranslationService(_FakeLanguageService(language), prefs))
    ..registerSingleton<TokenCostRepository>(_FakeTokenCosts())
    ..registerSingleton<SystemConfigService>(
        _FakeSystemConfig(lockedKeys: lockedKeys))
    ..registerSingleton<SubscriptionRepository>(_FakeSubscriptions());
}

Widget _app(Widget child, {required bool dark}) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    );

void _useNarrowPhone(WidgetTester tester, {double height = 700}) {
  tester.view.physicalSize = Size(320, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Color? _materialColorOf(WidgetTester tester, Finder card) => tester
    .widget<Material>(
        find.descendant(of: card, matching: find.byType(Material)).first)
    .color;

SavedGuideEntity _guide(String id, GuideType type, String title,
        {required DateTime at, String mode = 'standard', bool saved = false}) =>
    SavedGuideEntity(
      id: id,
      title: title,
      content: '',
      type: type,
      studyMode: mode,
      verseReference: type == GuideType.verse ? title : null,
      topicName: type == GuideType.topic ? title : null,
      createdAt: at,
      lastAccessedAt: at,
      isSaved: saved,
    );

/// Real translation table lookups for expectations.
class FakeTranslations {
  static String of(AppLanguage language, String key) {
    dynamic node = AppTranslations.translations[language];
    for (final part in key.split('.')) {
      node = (node as Map)[part];
    }
    return node as String;
  }
}

void main() {
  tearDown(() => GetIt.instance.reset());

  group('resolveInitialStudyMode', () {
    const all = StudyMode.values;

    test('a concrete saved mode wins', () {
      expect(resolveInitialStudyMode('deep', available: all), StudyMode.deep);
    });

    test('recommended, ask and unset use the recommended mode', () {
      for (final raw in [null, 'recommended', 'ask', 'bogus']) {
        expect(
            resolveInitialStudyMode(raw, available: all), recommendedStudyMode,
            reason: 'raw=$raw');
      }
    });

    test('a locked or hidden saved mode falls back', () {
      expect(
        resolveInitialStudyMode('sermon',
            available: all, locked: {StudyMode.sermon}),
        StudyMode.standard,
      );
      expect(
        resolveInitialStudyMode('deep',
            available: const [StudyMode.quick, StudyMode.deep],
            locked: {StudyMode.deep}),
        StudyMode.quick,
      );
    });
  });

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    group('$theme theme', () {
      setUp(() => _registerServices());

      testWidgets('depth cards: tap selects, selected is gold, costs shown',
          (tester) async {
        _useNarrowPhone(tester);
        var selected = StudyMode.standard;
        StudyMode? lockedTap;

        await tester.pumpWidget(_app(
          StatefulBuilder(
            builder: (context, setState) => Center(
              child: DepthModeCardRow(
                modes: StudyMode.values,
                selected: selected,
                costs: _costs,
                locked: const {StudyMode.sermon},
                onSelected: (m) => setState(() => selected = m),
                onLockedTap: (m) => lockedTap = m,
              ),
            ),
          ),
          dark: dark,
        ));
        await tester.pumpAndSettle();

        final standard = find.byKey(const ValueKey('depth_card_standard'));
        final selectedFill =
            ReaderPalette.of(tester.element(standard)).selectedFill;
        expect(_materialColorOf(tester, standard), selectedFill);
        expect(find.text('Standard'), findsOneWidget);
        expect(find.text('8 min'), findsOneWidget);
        expect(find.text('20'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('depth_card_quick')));
        await tester.pumpAndSettle();
        expect(selected, StudyMode.quick);
        expect(
          _materialColorOf(
              tester, find.byKey(const ValueKey('depth_card_quick'))),
          selectedFill,
        );
        expect(_materialColorOf(tester, standard), isNot(selectedFill));

        // Locked mode: scrolled into reach, tapping asks to upgrade instead
        // of selecting.
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('depth_card_sermon')),
          find.byType(ListView),
          const Offset(-120, 0),
        );
        await tester
            .ensureVisible(find.byKey(const ValueKey('depth_card_sermon')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('depth_card_sermon')));
        await tester.pumpAndSettle();
        expect(lockedTap, StudyMode.sermon);
        expect(selected, StudyMode.quick);
        expect(tester.takeException(), isNull);
      });

      testWidgets('generate button shows the selected mode cost',
          (tester) async {
        _useNarrowPhone(tester);
        var taps = 0;
        await tester.pumpWidget(_app(
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GenerateStudyButton(
                  label: 'Generate study',
                  cost: _costs[StudyMode.deep],
                  onPressed: () => taps++,
                ),
                const SizedBox(height: 12),
                GenerateStudyButton(
                  key: const Key('disabled'),
                  label: 'Generate study',
                  cost: 20,
                  enabled: false,
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
          dark: dark,
        ));

        expect(find.text('30'), findsOneWidget);
        await tester.tap(find.text('Generate study').first);
        await tester.tap(find.byKey(const Key('disabled')));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'depth chooser: full height, eyebrow, rows, start returns '
          'the chosen mode', (tester) async {
        _useNarrowPhone(tester, height: 780);
        Map<String, dynamic>? result;

        await tester.pumpWidget(_app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await ModeSelectionSheet.show(
                    context: context,
                    languageCode: 'en',
                    recommendedMode: StudyMode.standard,
                    preselectedMode: StudyMode.quick,
                    eyebrow: 'Forgiveness',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          dark: dark,
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('FORGIVENESS'), findsOneWidget);
        expect(find.text('How much time do you have?'), findsOneWidget);
        expect(find.text('Choose depth'), findsOneWidget);
        expect(find.text('Start Quick Read'), findsOneWidget);
        expect(find.text('Choose a study mode based on your available time'),
            findsOneWidget);
        // Full height: the sheet fills the screen below the safe area.
        expect(tester.getSize(find.byType(ModeSelectionSheet)).height,
            greaterThan(700));

        final quick = find.byKey(const ValueKey('mode_option_quick'));
        final sheetPalette = ReaderPalette.of(tester.element(quick));
        // Selected depth: the card fill with a gold wash and a gold ring.
        expect(
          tester
              .widget<Material>(find
                  .ancestor(of: quick, matching: find.byType(Material))
                  .first)
              .color,
          Color.alphaBlend(
              sheetPalette.selectedFill
                  .withValues(alpha: sheetPalette.isDark ? 0.10 : 0.08),
              sheetPalette.card),
        );

        // The last rows sit below the fold on a short phone.
        await tester.scrollUntilVisible(find.text('50–60 min'), 120,
            scrollable: find.byType(Scrollable).last);
        expect(find.text('50–60 min'), findsOneWidget);
        expect(find.text('40'), findsOneWidget);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('mode_option_deep')), -120,
            scrollable: find.byType(Scrollable).last);
        await tester
            .ensureVisible(find.byKey(const ValueKey('mode_option_deep')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('mode_option_deep')));
        await tester.pumpAndSettle();
        expect(find.text('Start Deep Dive'), findsOneWidget);

        await tester.tap(find.text('Remember my choice'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mode_selection_start')));
        await tester.pumpAndSettle();

        expect(result?['mode'], StudyMode.deep);
        expect(result?['rememberChoice'], isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('continue reading: two tinted cards, open, save, see all',
          (tester) async {
        _useNarrowPhone(tester);
        final now = DateTime(2026, 9, 29, 12);
        final opened = <String>[];
        final saved = <String>[];
        var seeAll = 0;

        await tester.pumpWidget(_app(
          Padding(
            padding: const EdgeInsets.all(20),
            child: ContinueReadingRow(
              now: now,
              guides: [
                _guide('a', GuideType.topic, 'Why Read the Bible?',
                    at: now.subtract(const Duration(minutes: 1))),
                _guide('b', GuideType.verse, 'John 3:16',
                    mode: 'quick',
                    saved: true,
                    at: now.subtract(const Duration(days: 1))),
                _guide('c', GuideType.topic, 'Hidden third',
                    at: now.subtract(const Duration(days: 2))),
              ],
              onOpen: (g) => opened.add(g.id),
              onSave: (g) => saved.add(g.id),
              onSeeAll: () => seeAll++,
            ),
          ),
          dark: dark,
        ));

        expect(find.text('Continue reading'), findsOneWidget);
        expect(find.text('Why Read the Bible?'), findsOneWidget);
        expect(find.text('John 3:16'), findsOneWidget);
        expect(find.text('Hidden third'), findsNothing);
        // Mode · duration · when.
        expect(find.text('Standard · 8 min · 1m ago'), findsOneWidget);
        expect(find.text('Quick Read · 3 min · 1d ago'), findsOneWidget);
        expect(find.text('Topic'), findsOneWidget);
        expect(find.text('Scripture'), findsOneWidget);

        await tester.tap(find.text('John 3:16'));
        await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
        await tester.tap(find.text('See all'));
        await tester.pump();

        expect(opened, ['b']);
        expect(saved, ['a']);
        expect(seeAll, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('header tabs and token pill fit 320pt', (tester) async {
        _useNarrowPhone(tester);
        var tab = 1;
        await tester.pumpWidget(_app(
          StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(children: [
                    const Expanded(child: Text('GENERATE A STUDY')),
                    TokenBalancePill(label: '40', onTap: () {}),
                  ]),
                  InputTypeTabs(
                    labels: const ['Scripture', 'Topic', 'Question'],
                    selectedIndex: tab,
                    onChanged: (i) => setState(() => tab = i),
                  ),
                ],
              ),
            ),
          ),
          dark: dark,
        ));
        await tester.tap(find.byKey(const ValueKey('input_type_tab_2')));
        await tester.pump();
        expect(tab, 2);
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final language in [AppLanguage.hindi, AppLanguage.malayalam]) {
    testWidgets('${language.code}: depth cards and chooser fit 320pt',
        (tester) async {
      await _registerServices(language: language);
      _useNarrowPhone(tester, height: 640);

      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Column(
            children: [
              DepthModeCardRow(
                modes: StudyMode.values,
                selected: StudyMode.standard,
                costs: _costs,
                onSelected: (_) {},
              ),
              TextButton(
                onPressed: () => ModeSelectionSheet.show(
                  context: context,
                  languageCode: language.code,
                  recommendedMode: StudyMode.standard,
                  eyebrow: 'क्षमा',
                ),
                child: const Text('open'),
              ),
            ],
          ),
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Localised, not English, labels.
      expect(find.text('Standard'), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('How much time do you have?'), findsNothing);
    });
  }

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);

    for (final language in AppLanguage.values) {
      testWidgets('${language.code}: depth chooser with a locked mode',
          (tester) async {
        await _registerServices(
            language: language, lockedKeys: const {'sermon_outline_mode'});
        tester.view.physicalSize = const Size(320, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ModeSelectionSheet.show(
                  context: context,
                  languageCode: language.code,
                  recommendedMode: StudyMode.standard,
                ),
                child: const Text('open'),
              ),
            ),
          ),
          dark: true,
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        // The subtitle and the locked row's label are back.
        expect(
            find.text(FakeTranslations.of(language, 'mode_selection.subtitle')),
            findsOneWidget);
        expect(
            find.text(FakeTranslations.of(language, 'learning_paths.locked')),
            findsOneWidget);
      });
    }
  });
}
