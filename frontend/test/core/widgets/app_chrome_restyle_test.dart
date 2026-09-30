import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/utils/version_checker.dart';
import 'package:disciplefy_bible_study/core/widgets/locked_feature_wrapper.dart';
import 'package:disciplefy_bible_study/core/widgets/offline_banner.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

const _languages = [
  AppLanguage.english,
  AppLanguage.hindi,
  AppLanguage.malayalam,
];

void main() {
  late FakeTranslationService translations;

  setUpAll(() async {
    await loadAppFonts();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDownAll(sl.reset);

  Widget app(Widget home, {required bool dark}) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: home,
      );

  group('showAppSnackBar', () {
    Future<void> show(
      WidgetTester tester, {
      required bool dark,
      AppSnackTone tone = AppSnackTone.neutral,
      String message = 'Saved',
      String? actionLabel,
      VoidCallback? onAction,
    }) async {
      await tester.pumpWidget(app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSnackBar(
                context,
                message,
                tone: tone,
                actionLabel: actionLabel,
                onAction: onAction,
              ),
              child: const Text('go'),
            ),
          ),
        ),
        dark: dark,
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'}: floating dark surface',
          (tester) async {
        await show(tester, dark: dark, tone: AppSnackTone.success);
        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.behavior, SnackBarBehavior.floating);
        expect(bar.persist, isFalse);
        expect(
          bar.backgroundColor,
          dark ? const Color(0xFF1F1F27) : const Color(0xFF16161D),
        );
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      });
    }

    testWidgets('tone picks the leading icon', (tester) async {
      await show(tester, dark: false, tone: AppSnackTone.error);
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_rounded));
      expect(icon.color, AppColors.error);
    });

    testWidgets('action runs its callback', (tester) async {
      var tapped = 0;
      await show(
        tester,
        dark: true,
        actionLabel: 'Open',
        onAction: () => tapped++,
      );
      await tester.tap(find.text('Open'));
      expect(tapped, 1);
    });

    testWidgets('a new message replaces the current one', (tester) async {
      await tester.pumpWidget(app(
        Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showAppSnackBar(context, 'first'),
                  child: const Text('a'),
                ),
                TextButton(
                  onPressed: () => showAppSnackBar(context, 'second'),
                  child: const Text('b'),
                ),
              ],
            ),
          ),
        ),
        dark: false,
      ));
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });
  });

  group('LockedFeatureScrim at 320x640', () {
    for (final dark in [false, true]) {
      for (final language in _languages) {
        testWidgets('${dark ? 'dark' : 'light'} ${language.code}',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          translations.language = language;
          addTearDown(() => translations.language = AppLanguage.english);
          await tester.pumpWidget(app(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 288,
                  height: 56,
                  child: Builder(
                    builder: (context) => LockedFeatureScrim(
                      label: translations
                          .getTranslation('app_chrome.lock.tap_to_upgrade'),
                    ),
                  ),
                ),
              ),
            ),
            dark: dark,
          ));
          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
          expectNoTruncatedText(tester);
        });
      }
    }
  });

  group('OfflineBanner', () {
    late _MockConnectivityBloc bloc;
    setUp(() => bloc = _MockConnectivityBloc());

    Future<void> pump(WidgetTester tester, ConnectivityState state,
        {required bool dark}) async {
      whenListen(bloc, const Stream<ConnectivityState>.empty(),
          initialState: state);
      await tester.pumpWidget(app(
        BlocProvider<ConnectivityBloc>.value(
          value: bloc,
          child: const Scaffold(body: OfflineBanner()),
        ),
        dark: dark,
      ));
      await tester.pumpAndSettle();
    }

    for (final dark in [false, true]) {
      for (final language in _languages) {
        testWidgets('${dark ? 'dark' : 'light'} ${language.code}: offline',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          translations.language = language;
          addTearDown(() => translations.language = AppLanguage.english);
          await pump(tester, ConnectivityOffline(), dark: dark);
          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
          expect(
            find.text(
                translations.getTranslation('app_chrome.offline.offline')),
            findsOneWidget,
          );
          expectNoTruncatedText(tester);
        });
      }
    }

    testWidgets('hidden while online', (tester) async {
      await pump(tester, ConnectivityOnline(), dark: false);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);
    });
  });

  group('AppUpdateDialog at 320x640', () {
    for (final dark in [false, true]) {
      for (final language in _languages) {
        for (final force in [true, false]) {
          testWidgets(
              '${dark ? 'dark' : 'light'} ${language.code} '
              '${force ? 'force' : 'optional'}', (tester) async {
            useSurface(tester, const Size(320, 640));
            translations.language = language;
            addTearDown(() => translations.language = AppLanguage.english);
            var primary = 0;
            var secondary = 0;
            String t(String key) =>
                translations.getTranslation('app_chrome.update.$key');
            await tester.pumpWidget(app(
              Scaffold(
                body: AppUpdateDialog(
                  icon: Icons.system_update_alt_rounded,
                  tone: force ? PopupTone.gold : PopupTone.indigo,
                  title: t(force ? 'required_title' : 'available_title'),
                  body: t(force ? 'required_body' : 'available_body'),
                  currentVersion: '1.2.3',
                  targetLabel: t(force ? 'required_version' : 'latest_version'),
                  targetVersion: '1.4.0',
                  hint: force ? t('required_hint') : null,
                  primaryLabel: t(force ? 'update_now' : 'update'),
                  onPrimary: () => primary++,
                  secondaryLabel: force ? null : t('later'),
                  onSecondary: force ? null : () => secondary++,
                ),
              ),
              dark: dark,
            ));
            expect(tester.takeException(), isNull);
            expect(find.text('1.2.3'), findsOneWidget);
            expect(find.text('1.4.0'), findsOneWidget);
            expectNoTruncatedText(tester);

            await tester.tap(find.byType(PopupPrimaryButton));
            expect(primary, 1);
            if (!force) {
              await tester.tap(find.byType(PopupTextButton));
              expect(secondary, 1);
            } else {
              expect(find.byType(PopupTextButton), findsNothing);
            }
          });
        }
      }
    }
  });
}
