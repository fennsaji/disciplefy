import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/font_scale_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/notifications/domain/entities/notification_preferences.dart';
import 'package:disciplefy_bible_study/features/notifications/domain/entities/time_of_day_vo.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_event.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/bloc/notification_state.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/pages/notification_settings_screen.dart';
import 'package:disciplefy_bible_study/features/settings/domain/entities/app_settings_entity.dart';
import 'package:disciplefy_bible_study/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_event.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/bloc/settings_state.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/pages/settings_screen.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheets.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';

import '../../helpers/welcome_test_harness.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class _FakeAuthStateProvider extends Fake
    with ChangeNotifier
    implements AuthStateProvider {
  @override
  bool get isAuthenticated => true;
  @override
  String get profileBasedDisplayName => 'Fenn';
  @override
  String get profileBasedDisplayNameOrEmpty => 'Fenn';
  @override
  String? get userEmail => 'gen.check@local.test';
  @override
  String? get profilePictureUrl => null;
  @override
  Map<String, dynamic>? get userProfile => const {
        'default_study_mode': 'standard',
        'learning_path_study_mode': 'recommended',
      };
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

  final user = User(
    id: 'u1',
    appMetadata: const {'provider': 'email'},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: 'gen.check@local.test',
  );

  setUpAll(() {
    registerFallbackValue(ThemeModeChanged(ThemeModeEntity.light()));
    registerFallbackValue(const LoadNotificationPreferences());
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<AuthStateProvider>(_FakeAuthStateProvider());
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
        // Email user without a verified flag: shows the verify banner.
        initialState: AuthenticatedState(user: user, profile: const {}));
    tokenBloc = _MockTokenBloc();
    whenListen(tokenBloc, const Stream<TokenState>.empty(),
        initialState: const TokenInitial());
    sl.registerSingleton<TokenBloc>(tokenBloc);
    connectivityBloc = _MockConnectivityBloc();
    whenListen(connectivityBloc, const Stream<ConnectivityState>.empty(),
        initialState: ConnectivityOnline());
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget app(Widget screen, {required bool dark}) {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => screen),
        GoRoute(path: '/', builder: (_, __) => const Text('stub:/')),
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

  /// Scrolls the settings list to the end so every row gets laid out.
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  group('SettingsScreen', () {
    for (final dark in [true, false]) {
      final theme = dark ? 'dark' : 'light';

      testWidgets('$theme: renders profile, banner and grouped sections',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const SettingsScreen(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Fenn'), findsOneWidget);
        expect(find.text('gen.check@local.test'), findsOneWidget);
        expect(find.text('F'), findsOneWidget); // avatar initial
        expect(find.text('Verify Your Email'), findsOneWidget);
        expect(find.text('Resend'), findsOneWidget);
        expect(find.text('YOU'), findsOneWidget);
        expect(find.text('PREFERENCES'), findsOneWidget);
        expect(find.text('System'), findsOneWidget); // theme value

        await scrollToEnd(tester);
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);
        expect(find.text('Delete Account'), findsOneWidget);
        expect(find.text('2.4.0'), findsOneWidget);
      });
    }

    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets(
            '320x640 ${language.code} ${dark ? 'dark' : 'light'}: no overflow',
            (tester) async {
          translations.language = language;
          useSurface(tester, const Size(320, 640));
          await tester.pumpWidget(app(const SettingsScreen(), dark: dark));
          await tester.pumpAndSettle();
          await scrollToEnd(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('theme sheet: picking Dark dispatches ThemeModeChanged(dark)',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const SettingsScreen(), dark: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemePreviewOption), findsNWidgets(3));
      expect(find.text("System follows your phone's light or dark setting."),
          findsOneWidget);

      await tester.tap(find.widgetWithText(ThemePreviewOption, 'Dark'));
      await tester.pumpAndSettle();

      verify(() => settingsBloc.add(ThemeModeChanged(ThemeModeEntity.dark())))
          .called(1);
      expect(find.byType(ThemePreviewOption), findsNothing); // sheet closed
    });

    testWidgets('theme sheet fits 320 wide in Malayalam', (tester) async {
      translations.language = AppLanguage.malayalam;
      useSurface(tester, const Size(320, 640));
      await tester.pumpWidget(app(const SettingsScreen(), dark: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.palette_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(ThemePreviewOption), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('NotificationSettingsScreen', () {
    late _MockNotificationBloc notificationBloc;

    setUp(() {
      notificationBloc = _MockNotificationBloc();
      whenListen(
        notificationBloc,
        const Stream<NotificationState>.empty(),
        initialState: NotificationPreferencesLoaded(
          permissionsGranted: true,
          preferences: NotificationPreferences(
            userId: 'u1',
            dailyVerseEnabled: true,
            recommendedTopicEnabled: true,
            streakReminderEnabled: true,
            streakMilestoneEnabled: true,
            streakLostEnabled: false,
            streakReminderTime: const TimeOfDayVO(hour: 20, minute: 0),
            memoryVerseReminderEnabled: true,
            memoryVerseOverdueEnabled: true,
            memoryVerseReminderTime: const TimeOfDayVO(hour: 9, minute: 0),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      sl.registerFactory<NotificationBloc>(() => notificationBloc);
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: groups and reminder time',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester
            .pumpWidget(app(const NotificationSettingsScreen(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('DAILY'), findsOneWidget);
        expect(find.text('STREAK'), findsOneWidget);
        expect(find.text('Reminders that help you keep going'), findsOneWidget);
        expect(find.text('8:00 PM'), findsOneWidget);
      });
    }

    testWidgets('toggling Daily verse dispatches the same update event',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(const NotificationSettingsScreen(), dark: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      verify(() => notificationBloc.add(
              const UpdateNotificationPreferences(dailyVerseEnabled: false)))
          .called(1);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester
            .pumpWidget(app(const NotificationSettingsScreen(), dark: true));
        await tester.pumpAndSettle();
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
