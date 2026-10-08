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
import 'package:disciplefy_bible_study/features/settings/presentation/pages/settings_more_page.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/pages/settings_screen.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
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

  User user({required bool anonymous}) => User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        isAnonymous: anonymous,
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
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: AuthenticatedState(
            user: user(anonymous: guest),
            profile: const {'email_verified': true}));
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

  Widget app({required bool dark, String initial = '/settings'}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
            path: '/settings/more',
            builder: (_, __) => const SettingsMorePage()),
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

  /// Every row of the list, laid out on a tall surface.
  void useTall(WidgetTester tester, {double width = 390}) =>
      useSurface(tester, Size(width, 3000));

  String tr(String key) => translations.getTranslation(key);

  testWidgets(
      'main Settings has ≤14 rows and a More row; policies live in More',
      (tester) async {
    setUpWorld(guest: false);
    useTall(tester);
    await tester.pumpWidget(app(dark: true));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsRow), findsAtLeastNWidgets(10));
    expect(tester.widgetList(find.byType(SettingsRow)).length,
        lessThanOrEqualTo(14));
    // Kept on the main list.
    for (final key in [
      TranslationKeys.gamificationTitle,
      TranslationKeys.settingsReflectionJournal,
      TranslationKeys.settingsMyPlan,
      TranslationKeys.settingsTheme,
      TranslationKeys.settingsAppLanguage,
      TranslationKeys.settingsContentLanguage,
      TranslationKeys.settingsNotifications,
      TranslationKeys.settingsOfflineGuides,
      TranslationKeys.settingsTextSize,
      TranslationKeys.settingsBlockedUsers,
      TranslationKeys.settingsSignOut,
      TranslationKeys.settingsDeleteAccount,
    ]) {
      expect(find.text(tr(key)), findsOneWidget, reason: key);
    }
    // Moved to More.
    expect(find.text('Privacy policy'), findsNothing);
    expect(find.text('Learning path study mode'), findsNothing);
    expect(find.text(tr(TranslationKeys.settingsFeedback)), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Learning path study mode'), findsOneWidget);
    for (final key in [
      TranslationKeys.settingsStudyModePreference,
      TranslationKeys.settingsRetakeQuestionnaire,
      TranslationKeys.settingsFeedback,
      TranslationKeys.settingsReportPurchaseIssue,
      TranslationKeys.settingsContactUs,
      TranslationKeys.settingsReplayWalkthrough,
      TranslationKeys.settingsSupportDeveloper,
      TranslationKeys.settingsBibleAttribution,
      TranslationKeys.settingsTermsOfService,
      TranslationKeys.settingsRefundPolicy,
      TranslationKeys.settingsAppVersion,
    ]) {
      expect(find.text(tr(key)), findsOneWidget, reason: key);
    }
    expect(find.text('2.4.0'), findsOneWidget);
  });

  testWidgets(
      'guest: Save progress on the main list; no purchase report in '
      'More', (tester) async {
    setUpWorld(guest: true);
    useTall(tester);
    await tester.pumpWidget(app(dark: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_guest_note')), findsOneWidget);
    expect(find.text(tr(TranslationKeys.settingsSaveProgress)), findsOneWidget);
    expect(find.text(tr(TranslationKeys.settingsSignOut)), findsNothing);
    expect(find.text(tr(TranslationKeys.settingsBlockedUsers)), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text(tr(TranslationKeys.settingsReportPurchaseIssue)),
        findsNothing);
  });

  for (final width in fitWidths) {
    for (final dark in [false, true]) {
      for (final language in AppLanguage.values) {
        final label = '${dark ? 'dark' : 'light'} ${language.code}';
        testWidgets('${width.toInt()}px $label: Settings fits', (tester) async {
          setUpWorld(guest: false);
          translations.language = language;
          useTall(tester, width: width);
          await tester.pumpWidget(app(dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });

        testWidgets('${width.toInt()}px $label: More fits', (tester) async {
          setUpWorld(guest: false);
          translations.language = language;
          useTall(tester, width: width);
          await tester.pumpWidget(app(dark: dark, initial: '/settings/more'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  }
}
