import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/milestone_celebration_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/options_menu_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_mode_info_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/streak_protection_dialog.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

void main() {
  late FakeTranslationService translations;

  setUpAll(loadAppFonts);

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async {
    await sl.reset();
  });

  /// Pumps an app whose home has one button calling [open].
  Future<void> pumpOpener(
    WidgetTester tester, {
    required bool dark,
    required void Function(BuildContext context) open,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(translations.language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    // Let the localization delegates load.
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void expectFits(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    expectNoTruncatedText(tester);
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: streak protection uses a freeze day', (tester) async {
      useSurface(tester, const Size(390, 844));
      var confirmed = 0;
      bool? result;
      await pumpOpener(
        tester,
        dark: dark,
        open: (context) async {
          result = await StreakProtectionDialog.show(
            context,
            freezeDaysAvailable: 2,
            currentStreak: 12,
            onConfirm: () => confirmed++,
          );
        },
      );

      expect(find.byType(PopupDialog), findsOneWidget);
      expect(find.text('Protect Your Streak'), findsOneWidget);
      expect(find.text('Your 12-day streak is at risk!'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('streak_protection_use')));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(result, isTrue);
    });

    testWidgets('$theme: streak protection cancel and no-freeze state',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      var confirmed = 0;
      bool? result;
      await pumpOpener(
        tester,
        dark: dark,
        open: (context) async {
          result = await StreakProtectionDialog.show(
            context,
            freezeDaysAvailable: 0,
            currentStreak: 3,
            onConfirm: () => confirmed++,
          );
        },
      );

      await tester.tap(find.byKey(const Key('streak_protection_use')));
      await tester.pumpAndSettle();
      expect(confirmed, 0, reason: 'disabled without freeze days');

      await tester.tap(find.byKey(const Key('streak_protection_cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.byType(PopupDialog), findsNothing);
    });

    testWidgets('$theme: milestone shows title, message and XP',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpOpener(
        tester,
        dark: dark,
        open: (context) => MilestoneCelebrationDialog.show(context,
            milestoneDays: 30, xpEarned: 150),
      );

      expect(find.text('STREAK MILESTONE'), findsOneWidget);
      expect(find.text('30-Day Streak!'), findsOneWidget);
      expect(find.text('+150 XP'), findsOneWidget);

      await tester.tap(find.byKey(const Key('milestone_celebration_continue')));
      await tester.pumpAndSettle();
      expect(find.byType(PopupDialog), findsNothing);
    });

    testWidgets('$theme: options sheet rows call their actions',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      final calls = <String>[];
      for (final row in const [
        ('memory_options_champions', 'champions'),
        ('memory_options_statistics', 'stats'),
        ('memory_options_sync', 'sync'),
        ('memory_options_reset', 'reset'),
      ]) {
        await pumpOpener(
          tester,
          dark: dark,
          open: (context) => OptionsMenuSheet.show(
            context,
            onSync: () => calls.add('sync'),
            onViewStatistics: () => calls.add('stats'),
            onReset: () => calls.add('reset'),
            onViewChampions: () => calls.add('champions'),
          ),
        );
        await tester.tap(find.byKey(Key(row.$1)));
        await tester.pumpAndSettle();
        expect(calls.last, row.$2);
        expect(find.byType(OptionsMenuSheet), findsNothing);
      }
    });

    testWidgets('$theme: practice mode info sheet closes on Got it',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpOpener(
        tester,
        dark: dark,
        open: (context) =>
            PracticeModeInfoSheet.show(context, PracticeModeType.flipCard),
      );
      expect(find.byType(PopupSheet), findsOneWidget);

      await tester.tap(find.byKey(const Key('practice_mode_info_got_it')));
      await tester.pumpAndSettle();
      expect(find.byType(PopupSheet), findsNothing);
    });

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: popups fit 320x640',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;

        final openers = <void Function(BuildContext)>[
          (c) => StreakProtectionDialog.show(c,
              freezeDaysAvailable: 5, currentStreak: 365, onConfirm: () {}),
          for (final days in const [10, 30, 100, 365, 7])
            (c) => MilestoneCelebrationDialog.show(c,
                milestoneDays: days, xpEarned: 500),
          (c) => OptionsMenuSheet.show(c,
              onSync: () {},
              onViewStatistics: () {},
              onReset: () {},
              onViewChampions: () {}),
          for (final mode in PracticeModeType.values)
            (c) => PracticeModeInfoSheet.show(c, mode),
        ];
        for (final open in openers) {
          await pumpOpener(tester, dark: dark, open: open);
          expectFits(tester);
          // Reset between popups.
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
