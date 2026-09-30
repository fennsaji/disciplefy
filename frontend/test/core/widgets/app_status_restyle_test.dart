import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/error_page.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/screens/maintenance_screen.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/core/widgets/offline_banner.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _FakeConfigService extends Fake implements SystemConfigService {
  int fetches = 0;
  bool fail = false;

  @override
  String get maintenanceModeMessage =>
      'We are upgrading the servers until 6 PM.';

  @override
  bool get isMaintenanceModeActive => true;

  @override
  Future<void> fetchSystemConfig({bool forceRefresh = false}) async {
    fetches++;
    if (fail) throw Exception('socket closed');
  }
}

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

  String t(String key) => translations.getTranslation(key);

  Widget app(Widget home, {required bool dark, Locale? locale}) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      );

  void useLanguage(AppLanguage language) {
    translations.language = language;
    addTearDown(() => translations.language = AppLanguage.english);
  }

  group('MaintenanceScreen at 320x640', () {
    for (final dark in [false, true]) {
      for (final language in _languages) {
        testWidgets('${dark ? 'dark' : 'light'} ${language.code}',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          useLanguage(language);
          final config = _FakeConfigService();
          await tester.pumpWidget(
            app(MaintenanceScreen(configService: config), dark: dark),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text(config.maintenanceModeMessage), findsOneWidget);
          expect(find.text(t('app_status.maintenance_title')), findsOneWidget);
          expectNoTruncatedText(tester);

          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          final page =
              ReaderPalette.of(tester.element(find.byType(MaintenanceScreen)))
                  .page;
          expect(scaffold.backgroundColor, page);

          await tester.tap(find.byKey(const Key('maintenance_check_status')));
          await tester.pumpAndSettle();
          expect(config.fetches, 1);
        });
      }
    }

    testWidgets('failed check shows a translated error snackbar',
        (tester) async {
      final config = _FakeConfigService()..fail = true;
      await tester.pumpWidget(
        app(MaintenanceScreen(configService: config), dark: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('maintenance_check_status')));
      await tester.pumpAndSettle();
      expect(
          find.text(t('app_status.maintenance_check_failed')), findsOneWidget);
      // Raw exception text is never shown to the user.
      expect(find.textContaining('socket closed'), findsNothing);
    });
  });

  group('ErrorPage at 320x640', () {
    Future<GoRouter> pump(WidgetTester tester,
        {required bool dark, required Locale locale}) async {
      final router = GoRouter(
        initialLocation: '/error',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home-stub')),
          ),
          GoRoute(
            path: '/error',
            builder: (_, __) =>
                const ErrorPage(error: 'network connection lost'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ));
      await tester.pumpAndSettle();
      return router;
    }

    for (final dark in [false, true]) {
      for (final language in _languages) {
        testWidgets('${dark ? 'dark' : 'light'} ${language.code}',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          useLanguage(language);
          await pump(tester, dark: dark, locale: Locale(language.code));

          expect(tester.takeException(), isNull);
          expect(find.byType(AppBar), findsNothing);
          expect(find.byKey(const Key('error_page_continue')), findsOneWidget);
          expect(find.byKey(const Key('error_page_retry')), findsOneWidget);
          expect(find.byKey(const Key('error_page_report')), findsOneWidget);
          expectNoTruncatedText(tester);
        });
      }
    }

    for (final key in [
      'error_page_continue',
      'error_page_retry',
      'error_page_home_icon',
    ]) {
      testWidgets('$key goes home', (tester) async {
        await pump(tester, dark: false, locale: const Locale('en'));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.text('home-stub'), findsOneWidget);
      });
    }
  });

  group('Exit confirmation', () {
    for (final dark in [false, true]) {
      for (final language in _languages) {
        testWidgets('${dark ? 'dark' : 'light'} ${language.code} at 320x640',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          useLanguage(language);
          await tester.pumpWidget(app(
            const AuthProtectedScreen(
              showExitConfirmation: true,
              child: Scaffold(body: Text('protected')),
            ),
            dark: dark,
          ));
          await tester.pumpAndSettle();
          tester
              .widget<PopScope>(find.byType(PopScope).last)
              .onPopInvokedWithResult
              ?.call(false, null);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(PopupDialog), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text(t('common.exit.title')), findsOneWidget);
          expectNoTruncatedText(tester);

          // Cancel closes the dialog and keeps the screen.
          await tester.tap(find.text(t('common.actions.cancel')));
          await tester.pumpAndSettle();
          expect(find.byType(PopupDialog), findsNothing);
          expect(find.text('protected'), findsOneWidget);
        });
      }
    }

    testWidgets('exit is the destructive pill', (tester) async {
      await tester.pumpWidget(app(
        const AuthProtectedScreen(
          showExitConfirmation: true,
          child: Scaffold(body: Text('protected')),
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      tester
          .widget<PopScope>(find.byType(PopScope).last)
          .onPopInvokedWithResult
          ?.call(false, null);
      await tester.pumpAndSettle();
      final exit = tester.widget<SettingsButton>(find.ancestor(
        of: find.text(t('common.exit.confirm')),
        matching: find.byType(SettingsButton),
      ));
      expect(exit.kind, SettingsButtonKind.destructive);
    });
  });

  group('OfflineBanner with a page below', () {
    late _MockConnectivityBloc bloc;
    setUp(() => bloc = _MockConnectivityBloc());

    Future<double> pageTopInset(
        WidgetTester tester, ConnectivityState state) async {
      whenListen(bloc, const Stream<ConnectivityState>.empty(),
          initialState: state);
      late double inset;
      await tester.pumpWidget(app(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: BlocProvider<ConnectivityBloc>.value(
            value: bloc,
            child: Scaffold(
              body: OfflineBanner(
                child: Builder(builder: (context) {
                  inset = MediaQuery.paddingOf(context).top;
                  return const SizedBox.expand();
                }),
              ),
            ),
          ),
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      return inset;
    }

    testWidgets('page drops its status-bar inset while offline',
        (tester) async {
      expect(await pageTopInset(tester, ConnectivityOffline()), 0);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('page keeps its status-bar inset while online', (tester) async {
      expect(await pageTopInset(tester, ConnectivityOnline()), 24);
    });
  });
}
