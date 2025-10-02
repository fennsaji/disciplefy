import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'features/daily_verse/data/services/daily_verse_cache_interface.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/study_generation/presentation/bloc/study_bloc.dart';
import 'features/saved_guides/data/models/saved_guide_model.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/phone_auth_bloc.dart';
import 'features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/tokens/presentation/bloc/token_bloc.dart';
import 'features/feedback/presentation/bloc/feedback_bloc.dart';
import 'core/utils/web_splash_controller.dart';
import 'core/services/theme_service.dart';
import 'core/services/auth_state_provider.dart';
import 'core/services/auth_session_validator.dart';
import 'core/utils/device_keyboard_handler.dart';
import 'core/utils/keyboard_animation_sync.dart';
import 'core/utils/custom_viewport_handler.dart';
import 'core/utils/keyboard_performance_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure URL strategy for web to use path-based routing instead of hash routing
  // This fixes OAuth callback issues where hash fragments interfere with redirect flow
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();

    // Register Hive adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SavedGuideModelAdapter());
    }

    await Hive.openBox('app_settings');

    // Validate and log configuration
    AppConfig.validateConfiguration();
    AppConfig.logConfiguration();

    // Initialize Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    // Initialize dependency injection
    if (kDebugMode) print('🔧 [MAIN] Initializing dependency injection...');
    await initializeDependencies();
    if (kDebugMode) print('✅ [MAIN] Dependency injection completed');

    // Initialize daily verse cache service
    if (kDebugMode) {
      print('🔧 [MAIN] Initializing daily verse cache service...');
    }
    await sl<DailyVerseCacheInterface>().initialize();
    if (kDebugMode) print('✅ [MAIN] Daily verse cache service completed');

    // Initialize theme service
    if (kDebugMode) print('🔧 [MAIN] Initializing theme service...');
    await sl<ThemeService>().initialize();
    if (kDebugMode) print('✅ [MAIN] Theme service completed');

    // Initialize Phase 2 & 3 keyboard shadow fixes (mobile only)
    if (!kIsWeb) {
      await DeviceKeyboardHandler.initialize();
      KeyboardAnimationSync.instance.initialize();
      CustomViewportHandler.instance.initialize();

      // Start performance monitoring in debug mode
      if (kDebugMode) {
        KeyboardPerformanceMonitor.instance.startMonitoring();
      }
    }

    if (kDebugMode) {
      print('🎉 [MAIN] All initialization completed, starting app...');
    }
    runApp(const DisciplefyBibleStudyApp());
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('🚨 [MAIN] Initialization error: $e');
      print('🚨 [MAIN] Stack trace: $stackTrace');
    }
    runApp(const ErrorApp());
  }
}

class DisciplefyBibleStudyApp extends StatefulWidget {
  const DisciplefyBibleStudyApp({super.key});

  @override
  State<DisciplefyBibleStudyApp> createState() =>
      _DisciplefyBibleStudyAppState();
}

class _DisciplefyBibleStudyAppState extends State<DisciplefyBibleStudyApp> {
  late AuthBloc _authBloc;
  late AuthStateProvider _authStateProvider;
  AuthSessionValidator? _authSessionValidator;

  @override
  void initState() {
    super.initState();

    // Initialize auth components
    _authBloc = sl<AuthBloc>()..add(const AuthInitializeRequested());
    _authStateProvider = sl<AuthStateProvider>();
    _authStateProvider.initialize(_authBloc);

    // Initialize auth session validator for Phase 3 monitoring (mobile only)
    if (!kIsWeb) {
      _authSessionValidator = AuthSessionValidator(_authBloc);
      _authSessionValidator?.register();
    }

    // Signal that Flutter is ready after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebSplashController.signalFlutterReady();
    });
  }

  @override
  void dispose() {
    _authSessionValidator?.unregister();
    _authStateProvider.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = sl<ThemeService>();

    return MultiBlocProvider(
      providers: [
        BlocProvider<StudyBloc>(
          create: (context) => sl<StudyBloc>(),
        ),
        BlocProvider<AuthBloc>.value(
          value: _authBloc,
        ),
        BlocProvider<PhoneAuthBloc>(
          create: (context) => sl<PhoneAuthBloc>(),
        ),
        BlocProvider<DailyVerseBloc>(
          create: (context) =>
              sl<DailyVerseBloc>()..add(const LoadTodaysVerse()),
        ),
        BlocProvider<SettingsBloc>(
          create: (context) => sl<SettingsBloc>(),
        ),
        BlocProvider<TokenBloc>(
          create: (context) => sl<TokenBloc>(),
        ),
        BlocProvider<FeedbackBloc>(
          create: (context) => sl<FeedbackBloc>(),
        ),
      ],
      child: ListenableBuilder(
        listenable: themeService,
        builder: (context, child) => MaterialApp.router(
          title: 'Disciplefy | Bible Study App',
          debugShowCheckedModeBanner: false,

          // Dynamic theming based on ThemeService
          themeMode: themeService.flutterThemeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,

          // Localization
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          // Navigation
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Disciplefy | Bible Study App - Error',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'App failed to initialize',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please check your configuration and try again.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
