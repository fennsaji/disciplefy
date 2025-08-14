import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'features/daily_verse/data/services/daily_verse_cache_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/study_generation/presentation/bloc/study_bloc.dart';
import 'features/saved_guides/data/models/saved_guide_model.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'core/utils/web_splash_controller.dart';
import 'core/services/theme_service.dart';
import 'core/services/auth_state_provider.dart';
import 'core/services/auth_session_validator.dart';

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
    await initializeDependencies();

    // Initialize daily verse cache service
    await sl<DailyVerseCacheService>().initialize();

    // Initialize theme service
    await sl<ThemeService>().initialize();

    runApp(const DisciplefyBibleStudyApp());
  } catch (e) {
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
  late AuthSessionValidator _authSessionValidator;

  @override
  void initState() {
    super.initState();

    // Initialize auth components
    _authBloc = sl<AuthBloc>()..add(const AuthInitializeRequested());
    _authStateProvider = sl<AuthStateProvider>();
    _authStateProvider.initialize(_authBloc);

    // Initialize auth session validator for Phase 3 monitoring
    _authSessionValidator = AuthSessionValidator(_authBloc);
    _authSessionValidator.register();

    // Signal that Flutter is ready after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebSplashController.signalFlutterReady();
    });
  }

  @override
  void dispose() {
    _authSessionValidator.unregister();
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
        BlocProvider<DailyVerseBloc>(
          create: (context) =>
              sl<DailyVerseBloc>()..add(const LoadTodaysVerse()),
        ),
        BlocProvider<SettingsBloc>(
          create: (context) => sl<SettingsBloc>(),
        ),
      ],
      child: ListenableBuilder(
        listenable: themeService,
        builder: (context, child) => MaterialApp.router(
          title: 'Disciplefy Bible Study',
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
        title: 'Disciplefy Bible Study - Error',
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
