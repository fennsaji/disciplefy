import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/self_assessment_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/tier_locked_mode_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/unlock_limit_exceeded_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_limit_exceeded_dialog.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _FakePricing extends Fake implements PricingService {
  static const prices = {
    'standard': '₹79/month',
    'plus': '₹149/month',
    'premium': '₹499/month',
  };

  @override
  String getFormattedPricePerMonth(String planCode, {String? provider}) =>
      prices[planCode] ?? '';
}

/// No DB config loaded: the dialogs fall back to their built-in plan lists.
class _NoConfig extends Fake implements SystemConfigService {
  @override
  SystemConfig? get config => null;
}

/// Recall rating sheet and the practice limit dialogs: popup styling, all
/// content kept, button actions, and no overflow at 320pt in en/hi/ml.
void main() {
  late FakeTranslationService translations;
  late List<String> visited;

  setUp(() {
    translations = FakeTranslationService();
    visited = [];
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<PricingService>(_FakePricing());
    sl.registerSingleton<SystemConfigService>(_NoConfig());
  });

  tearDown(() async => sl.reset());

  Widget app({
    required bool dark,
    required void Function(BuildContext context) open,
  }) {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/pricing',
        builder: (_, state) {
          visited.add('/pricing ${state.extra}');
          return const Scaffold(body: Text('pricing'));
        },
      ),
    ]);
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  Future<void> openWith(
    WidgetTester tester,
    void Function(BuildContext context) open, {
    bool dark = true,
    Size size = const Size(390, 844),
  }) async {
    useSurface(tester, size);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(dark: dark, open: open));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('Recall rating sheet', () {
    SelfAssessmentRating? picked;
    void open(BuildContext context) async {
      picked = await SelfAssessmentBottomSheet.show(context);
    }

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: popup sheet, recall copy',
          (tester) async {
        await openWith(tester, open, dark: dark);
        expect(find.byType(PopupSheet), findsOneWidget);
        expect(find.text('How well did you recall it?'), findsOneWidget);
        expect(find.text('Be honest — this sets your next review'),
            findsOneWidget);
        expect(find.textContaining('before seeing the answer'), findsNothing);
        for (final label in [
          "Didn't know it",
          'Knew a little',
          'Knew about half',
          'Knew most of it',
          'Knew it perfectly',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping a row returns that rating', (tester) async {
      picked = null;
      await openWith(tester, open);
      await tester.tap(find.byKey(const Key('self_assessment_knewMost')));
      await tester.pumpAndSettle();
      expect(picked, SelfAssessmentRating.knewMost);
      expect(picked!.qualityRating, 4);
      expect(find.byType(SelfAssessmentBottomSheet), findsNothing);
    });

    test('ratings run red to green', () {
      expect(
        SelfAssessmentRating.values.map((r) => r.tone.name).toList(),
        ['error', 'warning', 'gold', 'success', 'success'],
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        await openWith(tester, open, size: const Size(320, 640));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Daily review limit dialog', () {
    void open(BuildContext context) =>
        DailyReviewLimitDialog.show(context, currentTier: 'free');

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: popup with plan and prices',
          (tester) async {
        await openWith(tester, open, dark: dark);
        expect(find.byType(PopupDialog), findsOneWidget);
        expect(find.byType(PopupIconCircle), findsOneWidget);
        expect(find.text('Daily Limit Reached'), findsOneWidget);
        expect(find.textContaining('on the Free plan'), findsOneWidget);
        expect(
            find.text('Your Free Plan: 3 daily verse reviews'), findsOneWidget);
        expect(find.text('Get more daily reviews with:'), findsOneWidget);
        expect(find.text('Plus'), findsOneWidget);
        expect(find.text('₹149/month'), findsOneWidget);
        expect(find.text('Premium'), findsOneWidget);
        expect(find.text('Unlimited daily verse reviews'), findsOneWidget);
        expect(find.text('₹499/month'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Upgrade Now opens pricing on Standard', (tester) async {
      await openWith(tester, open);
      await tester.tap(find.text('Upgrade Now'));
      await tester.pumpAndSettle();
      expect(visited, ['/pricing {preselectedPlan: standard}']);
    });

    testWidgets('Maybe Later closes', (tester) async {
      await openWith(tester, open);
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyReviewLimitDialog), findsNothing);
      expect(visited, isEmpty);
    });
  });

  group('Daily unlock limit dialog', () {
    void open(BuildContext context) => UnlockLimitExceededDialog.show(
          context,
          unlockedModes: ['flip_card', 'word_bank'],
          unlockedCount: 2,
          limit: 2,
          tier: 'standard',
          verseReference: 'Philippians 4:13',
        );

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: counts, modes, plans, note',
          (tester) async {
        await openWith(tester, open, dark: dark);
        expect(find.byType(PopupDialog), findsOneWidget);
        expect(find.text('Daily Unlock Limit Reached'), findsOneWidget);
        expect(
            find.text('You\'ve unlocked 2 practice modes for '
                '"Philippians 4:13" today.'),
            findsOneWidget);
        expect(find.text('Modes Unlocked Today:'), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
        expect(find.text('Flip Card'), findsOneWidget);
        expect(find.text('Word Bank'), findsOneWidget);
        expect(find.text('Upgrade to unlock more modes per verse per day:'),
            findsOneWidget);
        for (final plan in ['Standard', 'Plus', 'Premium']) {
          expect(find.text(plan), findsOneWidget);
        }
        expect(find.text('2 modes per verse per day'), findsOneWidget);
        expect(find.text('3 modes per verse per day'), findsOneWidget);
        expect(find.text('All modes unlocked'), findsOneWidget);
        expect(find.text('₹79/month'), findsOneWidget);
        expect(find.textContaining('practice unlimited times'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('one unlocked mode reads in the singular', (tester) async {
      await openWith(
        tester,
        (context) => UnlockLimitExceededDialog.show(
          context,
          unlockedModes: ['flip_card'],
          unlockedCount: 1,
          limit: 1,
          tier: 'free',
          verseReference: 'John 3:16',
        ),
      );
      expect(
          find.text('You\'ve unlocked 1 practice mode for "John 3:16" today.'),
          findsOneWidget);
    });

    testWidgets('View Plans opens pricing, Maybe Later closes', (tester) async {
      await openWith(tester, open);
      await tester.ensureVisible(find.text('Maybe Later'));
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();
      expect(find.byType(UnlockLimitExceededDialog), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Plans'));
      await tester.tap(find.text('View Plans'));
      await tester.pumpAndSettle();
      expect(visited, ['/pricing {preselectedPlan: standard}']);
    });
  });

  group('Plan-locked mode dialog', () {
    void open(BuildContext context) => TierLockedModeDialog.show(
          context,
          mode: 'word_bank',
          currentTier: 'free',
          availableModes: ['flip_card', 'type_it_out'],
          requiredTier: 'standard',
          message: 'Word Bank needs the Standard plan.',
        );

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: included modes and plans',
          (tester) async {
        await openWith(tester, open, dark: dark);
        expect(find.byType(PopupDialog), findsOneWidget);
        expect(find.text('Upgrade Required'), findsOneWidget);
        expect(find.text('Word Bank needs the Standard plan.'), findsOneWidget);
        expect(find.text('Your Free Plan Includes:'), findsOneWidget);
        expect(find.text('Flip Card'), findsOneWidget);
        expect(find.text('Type It Out'), findsOneWidget);
        expect(
            find.text('Unlock advanced practice modes with:'), findsOneWidget);
        expect(find.text('All 8 practice modes + 2 modes per verse per day'),
            findsOneWidget);
        expect(find.text('All 8 practice modes + unlimited practice'),
            findsOneWidget);
        expect(find.text('₹499/month'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Upgrade Now opens pricing on Standard', (tester) async {
      await openWith(tester, open);
      await tester.ensureVisible(find.text('Upgrade Now'));
      await tester.tap(find.text('Upgrade Now'));
      await tester.pumpAndSettle();
      expect(visited, ['/pricing {preselectedPlan: standard}']);
    });
  });

  for (final language in AppLanguage.values) {
    testWidgets('limit dialogs fit 320x640 in ${language.code}',
        (tester) async {
      translations.language = language;
      for (final open in <void Function(BuildContext)>[
        (c) => DailyReviewLimitDialog.show(c, currentTier: 'free'),
        (c) => UnlockLimitExceededDialog.show(
              c,
              unlockedModes: ['flip_card', 'progressive'],
              unlockedCount: 2,
              limit: 2,
              tier: 'free',
              verseReference: 'Philippians 4:13',
            ),
        (c) => TierLockedModeDialog.show(
              c,
              mode: 'word_scramble',
              currentTier: 'free',
              availableModes: ['flip_card', 'type_it_out'],
              requiredTier: 'standard',
              message: 'Upgrade to use this mode.',
            ),
      ]) {
        await openWith(tester, open, size: const Size(320, 640));
        expect(tester.takeException(), isNull);
        // Button labels are never cut off (they may wrap, never ellipsize).
        for (final button in find.byType(PopupPrimaryButton).evaluate()) {
          final label = (button.widget as PopupPrimaryButton).label;
          final text = tester.renderObject<RenderParagraph>(find.descendant(
              of: find.byWidget(button.widget), matching: find.text(label)));
          expect(text.didExceedMaxLines, isFalse);
        }
      }
    });
  }
}
