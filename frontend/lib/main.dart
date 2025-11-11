import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'core/utils/web_splash_controller.dart';
import 'core/services/theme_service.dart';
import 'core/services/auth_state_provider.dart';
import 'core/services/auth_session_validator.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_service_web_stub.dart'
    if (dart.library.html) 'core/services/notification_service_web.dart';
import 'core/utils/device_keyboard_handler.dart';
import 'core/utils/keyboard_animation_sync.dart';
import 'core/utils/custom_viewport_handler.dart';
import 'core/utils/keyboard_performance_monitor.dart';
import 'core/services/android_hybrid_storage.dart';

// ============================================================================
// Firebase Configuration (Environment Variables)
// ============================================================================
// Use --dart-define to pass Firebase config for different environments
// Example: flutter run --dart-define=FIREBASE_API_KEY=your_key_here

const firebaseApiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: 'AIzaSyDfCd9JuqJKvi3Dq2pD87ZXe6bhVYWoSmc',
);
const firebaseAuthDomain = String.fromEnvironment(
  'FIREBASE_AUTH_DOMAIN',
  defaultValue: 'disciplefy---bible-study.firebaseapp.com',
);
const firebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'disciplefy---bible-study',
);
const firebaseStorageBucket = String.fromEnvironment(
  'FIREBASE_STORAGE_BUCKET',
  defaultValue: 'disciplefy---bible-study.firebasestorage.app',
);
const firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '16888340359',
);
const firebaseAppId = String.fromEnvironment(
  'FIREBASE_APP_ID',
  defaultValue: '1:16888340359:web:36ad4ae0d1ef1adf8e3d22',
);
const firebaseMeasurementId = String.fromEnvironment(
  'FIREBASE_MEASUREMENT_ID',
  defaultValue: 'G-TY0KDPH5TS',
);

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

    // Initialize Firebase for push notifications
    try {
      if (kDebugMode) print('🔧 [MAIN] Initializing Firebase...');

      if (kIsWeb) {
        // Initialize Firebase for web with environment-based configuration
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: firebaseApiKey,
            authDomain: firebaseAuthDomain,
            projectId: firebaseProjectId,
            storageBucket: firebaseStorageBucket,
            messagingSenderId: firebaseMessagingSenderId,
            appId: firebaseAppId,
            measurementId: firebaseMeasurementId,
          ),
        );
      } else {
        // Initialize Firebase for mobile platforms
        // Note: Requires firebase_options.dart generated via FlutterFire CLI
        await Firebase.initializeApp();

        // Set up background message handler (mobile only)
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }

      if (kDebugMode) print('✅ [MAIN] Firebase initialized successfully');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [MAIN] Firebase initialization error: $e');
        print('   For mobile: Run "flutterfire configure" to set up Firebase');
      }
    }

    // Initialize Supabase with platform-aware storage
    // Web: Uses default localStorage (reliable)
    // Android/iOS: Uses hybrid storage (SecureStorage + SharedPreferences fallback)
    if (kIsWeb) {
      // Web: Use default storage - browser localStorage is already reliable
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        debug: kDebugMode,
      );
      if (kDebugMode) {
        print('✅ [MAIN] Supabase initialized with default web storage');
      }
    } else {
      // Android/iOS: Use hybrid storage to protect against Keystore clearing
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        debug: kDebugMode,
        authOptions: FlutterAuthClientOptions(
          localStorage: await AndroidHybridStorage.create(),
        ),
      );
      if (kDebugMode) {
        print('✅ [MAIN] Supabase initialized with Android hybrid storage');
      }
    }

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
  NotificationService? _notificationService;
  NotificationServiceWeb? _notificationServiceWeb;

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

      // Initialize notification service (mobile only)
      _initializeNotifications();
    } else {
      // Initialize web notification service
      _initializeWebNotifications();
    }

    // Signal that Flutter is ready after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebSplashController.signalFlutterReady();
    });
  }

  /// Initialize push notification service (mobile)
  Future<void> _initializeNotifications() async {
    try {
      _notificationService = NotificationService(
        supabaseClient: sl(),
        router: AppRouter.router,
      );

      await _notificationService!.initialize();

      if (kDebugMode) {
        print('✅ [MAIN] NotificationService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [MAIN] NotificationService initialization failed: $e');
        print('   This is expected if Firebase is not configured yet');
      }
    }
  }

  /// Initialize web push notification service
  Future<void> _initializeWebNotifications() async {
    try {
      _notificationServiceWeb = NotificationServiceWeb(
        supabaseClient: sl(),
        router: AppRouter.router,
      );

      await _notificationServiceWeb!.initialize();

      if (kDebugMode) {
        print('✅ [MAIN] Web NotificationService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [MAIN] Web NotificationService initialization failed: $e');
        print('   This is expected if Firebase is not configured yet');
      }
    }
  }

  @override
  void dispose() {
    _authSessionValidator?.unregister();
    _notificationService?.dispose();
    _notificationServiceWeb?.dispose();
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
        BlocProvider<NotificationBloc>(
          create: (context) => sl<NotificationBloc>(),
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
