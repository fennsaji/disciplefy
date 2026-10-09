import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_session_widgets.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_start_view.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

import '../../../helpers/welcome_test_harness.dart';

VoiceQuotaEntity _quota({
  required int limit,
  required int remaining,
  String tier = 'standard',
}) =>
    VoiceQuotaEntity(
      canStart: limit < 0 || remaining > 0,
      quotaLimit: limit,
      quotaUsed: limit > 0 ? limit - remaining : 0,
      quotaRemaining: remaining,
      tier: tier,
    );

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDown(sl.reset);

  Widget start(QuotaDisplay? quota, {bool dark = false, String? language}) =>
      welcomeApp(
        dark: dark,
        language: language,
        screen: Scaffold(
          body: DisciplerStartView(
            quota: quota,
            languageName: 'English',
            onSettings: () {},
            onLanguageTap: () {},
            onStartTalking: () {},
            onType: () {},
            onSuggestion: (_) {},
          ),
        ),
      );

  group('QuotaDisplay', () {
    test('unlimited plans never show a pill', () {
      for (final q in [
        _quota(limit: 999999, remaining: 999999, tier: 'premium'),
        _quota(limit: -1, remaining: -1, tier: 'plus'),
        _quota(limit: 0, remaining: 0, tier: 'premium'),
      ]) {
        final display = QuotaDisplay(q, notifyQuota: true);
        expect(display.isVisible, isFalse, reason: '$q');
      }
    });

    test('a plan without Discipler is "not in plan", not exhausted', () {
      final display = QuotaDisplay(
        _quota(limit: 0, remaining: 0, tier: 'free'),
        notifyQuota: false,
      );
      expect(display.isNotInPlan, isTrue);
      expect(display.isExhausted, isFalse);
      expect(display.isVisible, isTrue);
    });

    test('warning only when none of a positive allowance is left', () {
      expect(
        QuotaDisplay(_quota(limit: 3, remaining: 1), notifyQuota: true)
            .isExhausted,
        isFalse,
      );
      expect(
        QuotaDisplay(_quota(limit: 3, remaining: 0), notifyQuota: false)
            .isExhausted,
        isTrue,
      );
    });
  });

  group('start view pill', () {
    testWidgets('hidden while the allowance is loading or failed',
        (tester) async {
      await tester.pumpWidget(start(null));
      await tester.pump();
      expect(find.byType(DisciplerQuotaChip), findsNothing);
      expect(find.textContaining('left this month'), findsNothing);
    });

    testWidgets('hidden on an unlimited plan', (tester) async {
      await tester.pumpWidget(start(QuotaDisplay(
        _quota(limit: 999999, remaining: 999999, tier: 'premium'),
        notifyQuota: true,
      )));
      await tester.pump();
      expect(find.byType(DisciplerQuotaChip), findsNothing);
    });

    testWidgets('plan without Discipler: calm "See plans" link',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(start(QuotaDisplay(
        _quota(limit: 0, remaining: 0, tier: 'free'),
        notifyQuota: true,
        onSeePlans: () => opened++,
      )));
      await tester.pump();
      expect(find.text('Not in your plan · See plans'), findsOneWidget);
      expect(find.textContaining('0 of 0'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      await tester.tap(find.text('Not in your plan · See plans'));
      expect(opened, 1);
    });

    testWidgets('N per month: "{left} of {N} left this month"', (tester) async {
      await tester.pumpWidget(start(QuotaDisplay(
        _quota(limit: 3, remaining: 2),
        notifyQuota: true,
      )));
      await tester.pump();
      expect(find.text('2 of 3 left this month'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('none left of N: deep red warning', (tester) async {
      await tester.pumpWidget(start(QuotaDisplay(
        _quota(limit: 3, remaining: 0),
        notifyQuota: false,
      )));
      await tester.pump();
      expect(find.text('0 of 3 left this month'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      final label = tester.widget<Text>(find.text('0 of 3 left this month'));
      expect(label.style!.color, const Color(0xFF991B1B));
    });

    for (final language in ['hi', 'ml']) {
      testWidgets('$language strings resolve and fit at 320pt', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(start(
          QuotaDisplay(_quota(limit: 0, remaining: 0, tier: 'free'),
              notifyQuota: true),
          language: language,
        ));
        await tester.pump();
        expect(find.textContaining('voice_buddy.'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('contrast over the header photo', () {
    // Worst pixels the photo can put under the header, light and dark.
    const worst = [disciplerPhotoDarkestPixel, disciplerPhotoLightestPixel];

    Color fillOf(WidgetTester tester) {
      final box = tester.widget<Container>(find.descendant(
        of: find.byType(DisciplerQuotaChip),
        matching: find.byType(Container),
      ));
      return (box.decoration! as BoxDecoration).color!;
    }

    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';
      for (final remaining in [2, 0]) {
        testWidgets('$theme pill ($remaining left) is opaque and >= 5.5:1',
            (tester) async {
          await tester.pumpWidget(start(
            QuotaDisplay(_quota(limit: 3, remaining: remaining),
                notifyQuota: true),
            dark: dark,
          ));
          await tester.pump();
          final fill = fillOf(tester);
          expect(fill.a, 1.0, reason: 'a translucent pill shows the photo');
          final label = tester
              .widget<Text>(find.text('$remaining of 3 left this month'))
              .style!
              .color!;
          for (final pixel in worst) {
            final behind = Color.alphaBlend(fill, pixel);
            expect(contrastRatio(label, behind),
                greaterThanOrEqualTo(kMinContrastChipLabel));
          }
        });
      }

      testWidgets('$theme header text and icons hold over the worst pixel',
          (tester) async {
        await tester.pumpWidget(start(null, dark: dark));
        await tester.pump();
        final palette = ReaderPalette.resolve(
          isDark: dark,
          page: dark ? AppColors.darkScaffold : AppColors.lightScaffold,
        );
        final backdrop = tester
            .widget<WelcomePhotoBackdrop>(find.byType(WelcomePhotoBackdrop));
        expect(backdrop.headerScrim, isTrue);

        // Every scrim stop composited over each worst pixel.
        final behind = [
          for (final stop in photoHeaderScrim(palette))
            for (final pixel in worst) Color.alphaBlend(stop, pixel),
        ];
        Color colorOf(String text) =>
            tester.widget<Text>(find.text(text)).style!.color!;
        final roles = {
          'eyebrow': colorOf('DISCIPLER'),
          'title': colorOf('Ask Discipler anything'),
          'description': colorOf('Your Bible companion — by voice or text'),
        };
        for (final role in roles.entries) {
          for (final bg in behind) {
            expect(contrastRatio(role.value, bg),
                greaterThanOrEqualTo(kMinContrastNormalText),
                reason: '${role.key} on $bg');
          }
        }

        // The gear sits on its own opaque round fill.
        final gear = tester.widget<SessionRoundButton>(find.ancestor(
          of: find.byIcon(Icons.settings_outlined),
          matching: find.byType(SessionRoundButton),
        ));
        expect(gear.fill.a, 1.0);
        expect(contrastRatio(gear.ink, gear.fill),
            greaterThanOrEqualTo(kMinContrastChipLabel));
      });
    }
  });
}
