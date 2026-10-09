import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/font_scale_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/settings/domain/entities/app_settings_entity.dart';
import 'package:disciplefy_bible_study/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_event.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_state.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/pages/settings_screen.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';

import '../../helpers/fit_matrix.dart';
import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _FakeAuthStateProvider extends Fake
    with ChangeNotifier
    implements AuthStateProvider {
  @override
  bool get isAuthenticated => true;
  @override
  String get profileBasedDisplayName => 'Guest';
  @override
  String get profileBasedDisplayNameOrEmpty => '';
  @override
  String? get userEmail => null;
  @override
  String? get profilePictureUrl => null;
  @override
  Map<String, dynamic>? get userProfile => null;
}

class _FakeGuestSession extends Fake implements GuestSessionService {
  final bool guest;
  _FakeGuestSession(this.guest);
  @override
  bool get isGuest => guest;
}

class _FakeDownloads extends Fake implements LearningPathDownloadService {
  @override
  Future<List<LearningPathDownloadModel>> getAllDownloads() async => [];
}

class _FakeLanguagePrefs extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get studyContentLanguageChanges => const Stream.empty();
  @override
  Future<bool> isStudyContentLanguageDefault() async => true;
  @override
  Future<AppLanguage> getStudyContentLanguage() async => AppLanguage.english;
}

class _FakeSystemConfig extends Fake implements SystemConfigService {
  @override
  bool shouldHideFeature(String featureKey, String userPlan) => false;
  @override
  bool hasFeatureAccess(String featureKey, String userPlan) => true;
  @override
  bool isFeatureLocked(String featureKey, String userPlan) => false;
}

void main() {
  late FakeTranslationService translations;
  late _MockSettingsBloc settingsBloc;
  late MockAuthBloc authBloc;
  late _MockTokenBloc tokenBloc;
  late _MockConnectivityBloc connectivityBloc;

  final anon = User(
    id: 'g1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    isAnonymous: true,
  );

  setUpAll(loadAppFonts);

  void setUpWorld({required bool guest}) {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<AuthStateProvider>(_FakeAuthStateProvider());
    sl.registerSingleton<GuestSessionService>(_FakeGuestSession(guest));
    sl.registerSingleton<LearningPathDownloadService>(_FakeDownloads());
    sl.registerSingleton<LanguagePreferenceService>(_FakeLanguagePrefs());
    sl.registerSingleton<SystemConfigService>(_FakeSystemConfig());
    sl.registerSingleton<FontScaleService>(FontScaleService());

    settingsBloc = _MockSettingsBloc();
    whenListen(
      settingsBloc,
      const Stream<SettingsState>.empty(),
      initialState: SettingsLoaded(
        settings: AppSettingsEntity(
          themeMode: ThemeModeEntity.system(isDarkMode: false),
          language: 'en',
          notificationsEnabled: true,
          appVersion: '2.4.0',
        ),
      ),
    );
    authBloc = MockAuthBloc();
    // Profile is empty: an email user in this state would see the banner.
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: AuthenticatedState(user: anon, profile: const {}));
    tokenBloc = _MockTokenBloc();
    whenListen(tokenBloc, const Stream<TokenState>.empty(),
        initialState: const TokenInitial());
    sl.registerSingleton<TokenBloc>(tokenBloc);
    connectivityBloc = _MockConnectivityBloc();
    whenListen(connectivityBloc, const Stream<ConnectivityState>.empty(),
        initialState: ConnectivityOnline());
  }

  tearDown(() async {
    await sl.reset();
  });

  Widget app({required bool dark}) {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<TokenBloc>.value(value: tokenBloc),
        BlocProvider<ConnectivityBloc>.value(value: connectivityBloc),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ),
    );
  }

  Future<void> scrollToEnd(WidgetTester tester,
      {void Function()? check}) async {
    check?.call();
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      check?.call();
    }
  }

  String tr(String key) => translations.getTranslation(key);

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: guest sees Save progress, not Sign out or Delete',
        (tester) async {
      setUpWorld(guest: true);
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(dark: dark));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_guest_note')), findsOneWidget);
      expect(find.text(tr(TranslationKeys.settingsGuestNote)), findsOneWidget);
      expect(find.text('Verify Your Email'), findsNothing);
      expect(find.text('Resend Verification Email'), findsNothing);
      // Rows a guest keeps.
      expect(find.text(tr(TranslationKeys.gamificationTitle)), findsOneWidget);
      expect(find.text(tr(TranslationKeys.settingsMyPlan)), findsOneWidget);

      await scrollToEnd(tester);
      expect(
          find.text(tr(TranslationKeys.settingsSaveProgress)), findsOneWidget);
      expect(find.text(tr(TranslationKeys.settingsSignOut)), findsNothing);
      expect(
          find.text(tr(TranslationKeys.settingsDeleteAccount)), findsNothing);
      expect(find.text(tr(TranslationKeys.settingsBlockedUsers)), findsNothing);
    });

    for (final width in fitWidths) {
      for (final language in AppLanguage.values) {
        testWidgets(
            '${width.toInt()}x640 $theme ${language.code}: guest section fits',
            (tester) async {
          setUpWorld(guest: true);
          translations.language = language;
          useSurface(tester, Size(width, 640));
          await tester.pumpWidget(app(dark: dark));
          await tester.pumpAndSettle();
          await scrollToEnd(tester, check: () => expectNoTruncatedText(tester));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('full account keeps Sign out and Delete (no regression)',
      (tester) async {
    setUpWorld(guest: false);
    useSurface(tester, const Size(390, 844));
    await tester.pumpWidget(app(dark: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings_guest_note')), findsNothing);
    await scrollToEnd(tester);
    expect(find.text(tr(TranslationKeys.settingsSignOut)), findsOneWidget);
    expect(
        find.text(tr(TranslationKeys.settingsDeleteAccount)), findsOneWidget);
    expect(find.text(tr(TranslationKeys.settingsSaveProgress)), findsNothing);
  });
}
