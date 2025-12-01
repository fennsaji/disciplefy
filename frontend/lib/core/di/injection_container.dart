import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../network/network_info.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/domain/repositories/storage_repository.dart';
import '../../features/auth/data/repositories/storage_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../features/auth/data/repositories/auth_session_repository_impl.dart';
import '../../features/auth/domain/repositories/secure_store_repository.dart';
import '../../features/auth/data/repositories/secure_store_repository_impl.dart';
import '../../features/auth/domain/repositories/local_store_repository.dart';
import '../../features/auth/data/repositories/local_store_repository_impl.dart';
import '../../features/auth/domain/usecases/clear_user_data_usecase.dart';
import '../../features/auth/data/datasources/phone_auth_remote_datasource.dart';
import '../../features/auth/domain/repositories/phone_auth_repository.dart';
import '../../features/auth/data/repositories/phone_auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/phone_auth_bloc.dart';
import '../../features/study_generation/domain/repositories/study_repository.dart';
import '../../features/study_generation/data/repositories/study_repository_impl.dart';
import '../../features/study_generation/data/datasources/study_remote_data_source.dart';
import '../../features/study_generation/data/datasources/study_local_data_source.dart';
import '../../features/study_generation/domain/usecases/generate_study_guide.dart';
import '../../features/study_generation/domain/usecases/get_default_study_language.dart';
import '../../features/study_generation/domain/services/input_validation_service.dart';
import '../../features/study_generation/presentation/bloc/study_bloc.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/data/datasources/settings_local_data_source.dart';
import '../../features/settings/domain/usecases/get_settings.dart';
import '../../features/settings/domain/usecases/update_theme_mode.dart';
import '../../features/settings/domain/usecases/get_app_version.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../features/daily_verse/data/services/daily_verse_api_service.dart';
import '../../features/daily_verse/data/services/daily_verse_cache_service.dart';
import '../../features/daily_verse/data/services/daily_verse_web_cache_service.dart';
import '../../features/daily_verse/data/services/daily_verse_cache_interface.dart';
import '../../features/daily_verse/domain/repositories/daily_verse_repository.dart';
import '../../features/daily_verse/data/repositories/daily_verse_repository_impl.dart';
import '../../features/daily_verse/domain/repositories/streak_repository.dart';
import '../../features/daily_verse/data/repositories/streak_repository_impl.dart';
import '../../features/daily_verse/domain/usecases/get_daily_verse.dart';
import '../../features/daily_verse/domain/usecases/get_cached_verse.dart';
import '../../features/daily_verse/domain/usecases/manage_verse_preferences.dart';
import '../../features/daily_verse/domain/usecases/get_default_language.dart';
import '../../features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../features/saved_guides/data/services/study_guides_api_service.dart';
import '../../features/saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import '../../features/saved_guides/domain/repositories/saved_guides_repository.dart';
import '../../features/saved_guides/data/repositories/saved_guides_repository_impl.dart';
import '../../features/saved_guides/data/datasources/saved_guides_local_data_source.dart';
import '../../features/saved_guides/data/datasources/saved_guides_remote_data_source.dart';
import '../../features/saved_guides/domain/usecases/get_saved_guides_with_sync.dart';
import '../../features/saved_guides/domain/usecases/get_recent_guides_with_sync.dart';
import '../../features/saved_guides/domain/usecases/toggle_save_guide_api.dart';
import '../../features/study_generation/data/services/save_guide_api_service.dart';
import '../../features/feedback/data/datasources/feedback_remote_datasource.dart';
import '../../features/feedback/data/datasources/feedback_remote_datasource_impl.dart';
import '../../features/feedback/data/repositories/feedback_repository_impl.dart';
import '../../features/feedback/domain/repositories/feedback_repository.dart';
import '../../features/feedback/domain/usecases/submit_feedback_usecase.dart';
import '../../features/feedback/presentation/bloc/feedback_bloc.dart';
import '../../features/home/data/services/recommended_guides_service.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/home/presentation/bloc/recommended_topics_bloc.dart';
import '../../features/home/presentation/bloc/home_study_generation_bloc.dart';
import '../../features/onboarding/data/datasources/onboarding_local_datasource.dart';
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/onboarding/domain/usecases/get_onboarding_state.dart';
import '../../features/onboarding/domain/usecases/save_language_preference.dart';
import '../../features/onboarding/domain/usecases/complete_onboarding.dart';
import '../../features/onboarding/presentation/bloc/onboarding_bloc.dart';
import '../../features/user_profile/data/repositories/user_profile_repository_impl.dart';
import '../../features/user_profile/data/services/user_profile_service.dart';
import '../../features/user_profile/domain/repositories/user_profile_repository.dart';
import '../../features/user_profile/domain/usecases/get_user_profile.dart';
import '../../features/user_profile/domain/usecases/update_user_profile.dart';
import '../../features/user_profile/domain/usecases/delete_user_profile.dart';
import '../../features/user_profile/presentation/bloc/user_profile_bloc.dart';
import '../../features/study_topics/data/datasources/study_topics_remote_datasource.dart';
import '../../features/study_topics/data/datasources/topic_progress_remote_datasource.dart';
import '../../features/study_topics/data/repositories/study_topics_repository_impl.dart';
import '../../features/study_topics/data/repositories/topic_progress_repository_impl.dart';
import '../../features/study_topics/domain/repositories/study_topics_repository.dart';
import '../../features/study_topics/domain/repositories/topic_progress_repository.dart';
import '../../features/study_topics/presentation/bloc/study_topics_bloc.dart';
import '../../features/study_topics/data/datasources/learning_paths_remote_datasource.dart';
import '../../features/study_topics/data/repositories/learning_paths_repository_impl.dart';
import '../../features/study_topics/domain/repositories/learning_paths_repository.dart';
import '../../features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import '../../features/study_topics/presentation/bloc/continue_learning_bloc.dart';
import '../services/theme_service.dart';
import '../services/auth_state_provider.dart';
import '../services/language_preference_service.dart';
import '../services/language_cache_coordinator.dart';
import '../services/http_service.dart';
import '../services/personal_notes_api_service.dart';
import '../i18n/translation_service.dart';
import '../../features/study_generation/domain/repositories/personal_notes_repository.dart';
import '../../features/study_generation/data/repositories/personal_notes_repository_impl.dart';
import '../../features/study_generation/domain/usecases/manage_personal_notes.dart';
import '../../features/user_profile/data/services/user_profile_api_service.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/check_notification_permissions.dart'
    as check_permissions_usecase;
import '../../features/notifications/domain/usecases/get_notification_preferences.dart'
    as get_preferences_usecase;
import '../../features/notifications/domain/usecases/update_notification_preferences.dart'
    as update_preferences_usecase;
import '../../features/notifications/domain/usecases/request_notification_permissions.dart'
    as request_permissions_usecase;
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../services/notification_service.dart';
import '../navigation/study_navigator.dart';
import '../navigation/go_router_study_navigator.dart';
import '../router/app_router.dart';
import '../../features/tokens/data/datasources/token_remote_data_source.dart';
import '../../features/tokens/data/repositories/token_repository_impl.dart';
import '../../features/tokens/data/repositories/payment_method_repository_impl.dart';
import '../../features/tokens/domain/repositories/token_repository.dart';
import '../../features/tokens/domain/repositories/payment_method_repository.dart';
import '../../features/tokens/domain/usecases/get_token_status.dart';
import '../../features/tokens/domain/usecases/get_payment_methods.dart';
import '../../features/tokens/domain/usecases/save_payment_method.dart';
import '../../features/tokens/domain/usecases/set_default_payment_method.dart';
import '../../features/tokens/domain/usecases/delete_payment_method.dart';
import '../../features/tokens/domain/usecases/get_payment_preferences.dart';
import '../../features/tokens/domain/usecases/update_payment_preferences.dart';
import '../../features/tokens/domain/usecases/confirm_payment.dart';
import '../../features/tokens/domain/usecases/create_payment_order.dart';
import '../../features/tokens/domain/usecases/get_purchase_history.dart';
import '../../features/tokens/domain/usecases/get_purchase_statistics.dart';
import '../../features/tokens/presentation/bloc/token_bloc.dart';
import '../../features/tokens/presentation/bloc/payment_method_bloc.dart';
import '../../features/tokens/di/tokens_injection.dart';
import '../../features/follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import '../../features/follow_up_chat/data/services/conversation_service.dart';
import '../../features/subscription/data/datasources/subscription_remote_data_source.dart';
import '../../features/subscription/data/repositories/subscription_repository_impl.dart';
import '../../features/subscription/domain/repositories/subscription_repository.dart';
import '../../features/subscription/domain/usecases/create_subscription.dart';
import '../../features/subscription/domain/usecases/cancel_subscription.dart';
import '../../features/subscription/domain/usecases/resume_subscription.dart';
import '../../features/subscription/domain/usecases/get_active_subscription.dart';
import '../../features/subscription/domain/usecases/get_subscription_history.dart';
import '../../features/subscription/domain/usecases/get_invoices.dart';
import '../../features/subscription/presentation/bloc/subscription_bloc.dart';
import '../../features/memory_verses/data/datasources/memory_verse_local_datasource.dart';
import '../../features/memory_verses/data/datasources/memory_verse_remote_datasource.dart';
import '../../features/memory_verses/data/repositories/memory_verse_repository_impl.dart';
import '../../features/memory_verses/domain/repositories/memory_verse_repository.dart';
import '../../features/memory_verses/domain/usecases/get_due_verses.dart';
import '../../features/memory_verses/domain/usecases/add_verse_from_daily.dart';
import '../../features/memory_verses/domain/usecases/add_verse_manually.dart';
import '../../features/memory_verses/domain/usecases/submit_review.dart';
import '../../features/memory_verses/domain/usecases/get_statistics.dart';
import '../../features/memory_verses/domain/usecases/fetch_verse_text.dart';
import '../../features/memory_verses/domain/usecases/delete_verse.dart';
import '../../features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import '../../features/voice_buddy/data/datasources/voice_buddy_remote_data_source.dart';
import '../../features/voice_buddy/data/repositories/voice_buddy_repository_impl.dart';
import '../../features/voice_buddy/data/services/speech_service.dart';
import '../../features/voice_buddy/data/services/tts_service.dart';
import '../../features/voice_buddy/domain/repositories/voice_buddy_repository.dart';
import '../../features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import '../../features/voice_buddy/presentation/bloc/voice_preferences_bloc.dart';

/// Service locator instance for dependency injection
final sl = GetIt.instance;

/// Initialize all dependencies for the application
/// Call this before runApp() in main.dart
Future<void> initializeDependencies() async {
  //! Core
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => Supabase.instance.client);
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl()),
  );

  // Register SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  //! Navigation
  sl.registerLazySingleton<StudyNavigator>(
    () => GoRouterStudyNavigator(),
  );

  // Register ThemeService
  sl.registerLazySingleton(() => ThemeService());

  // Register HttpService
  sl.registerLazySingleton(() => HttpService(httpClient: sl()));

  // Register Personal Notes API Service (Data Layer)
  sl.registerLazySingleton<PersonalNotesApiService>(
    () => PersonalNotesApiService(httpClient: sl()),
  );

  // Register Personal Notes Repository (Domain Layer)
  sl.registerLazySingleton<PersonalNotesRepository>(
    () => PersonalNotesRepositoryImpl(apiService: sl()),
  );

  // Register Personal Notes Use Case (Domain Layer)
  sl.registerLazySingleton<ManagePersonalNotesUseCase>(
    () => ManagePersonalNotesUseCase(repository: sl()),
  );

  // Register User Profile API Service
  sl.registerLazySingleton(() => UserProfileApiService(
        httpService: sl<HttpService>(),
      ));

  // Register Language Cache Coordinator
  sl.registerLazySingleton(() => LanguageCacheCoordinator());

  // Register Language Preference Service
  sl.registerLazySingleton(() => LanguagePreferenceService(
        prefs: sl(),
        authService: sl(),
        authStateProvider: sl(),
        userProfileService: sl(),
        cacheCoordinator: sl(),
      ));

  // Register Translation Service
  sl.registerLazySingleton(() => TranslationService(sl(), sl()));

  //! Auth
  sl.registerLazySingleton(() => AuthService());
  sl.registerFactory(() => AuthBloc(authService: sl()));

  // Phone Auth DataSource
  sl.registerLazySingleton<PhoneAuthRemoteDataSource>(
    () => PhoneAuthRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );

  // Phone Auth Repository
  sl.registerLazySingleton<PhoneAuthRepository>(
    () => PhoneAuthRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  // Phone Auth BLoC
  sl.registerFactory(() => PhoneAuthBloc(
        phoneAuthRepository: sl(),
      ));

  // Register AuthStateProvider as singleton for consistent state across screens
  sl.registerLazySingleton(() => AuthStateProvider());

  // Storage Repository and Use Cases
  sl.registerLazySingleton<StorageRepository>(() => StorageRepositoryImpl());
  sl.registerLazySingleton<AuthSessionRepository>(
      () => AuthSessionRepositoryImpl());
  sl.registerLazySingleton<SecureStoreRepository>(
      () => SecureStoreRepositoryImpl());
  sl.registerLazySingleton<LocalStoreRepository>(
      () => LocalStoreRepositoryImpl());
  sl.registerLazySingleton(() => ClearUserDataUseCase(
        authSessionRepository: sl(),
        secureStoreRepository: sl(),
        localStoreRepository: sl(),
        storageRepository: sl(), // Legacy - for backward compatibility
      ));

  //! Study Generation Data Sources
  sl.registerLazySingleton<StudyRemoteDataSource>(
    () => StudyRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );

  sl.registerLazySingleton<StudyLocalDataSource>(
    () => StudyLocalDataSourceImpl(),
  );

  //! Study Generation Repository
  sl.registerLazySingleton<StudyRepository>(
    () => StudyRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton(() => GenerateStudyGuide(sl()));
  sl.registerLazySingleton(() => GetDefaultStudyLanguage(sl()));

  sl.registerLazySingleton(() => InputValidationService());

  sl.registerFactory(() => StudyBloc(
        generateStudyGuide: sl(),
        saveGuideService: sl(),
        managePersonalNotes: sl<ManagePersonalNotesUseCase>(),
        validationService: sl(),
        authService: sl(),
      ));

  //! Settings
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(),
  );

  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetSettings(sl()));
  sl.registerLazySingleton(() => UpdateThemeMode(sl()));
  sl.registerLazySingleton(() => GetAppVersion(sl()));

  sl.registerLazySingleton(
    () => SettingsBloc(
      getSettings: sl(),
      updateThemeMode: sl(),
      getAppVersion: sl(),
      settingsRepository: sl(),
      themeService: sl(),
      languagePreferenceService: sl(),
    ),
    dispose: (bloc) => bloc.close(),
  );

  //! Daily Verse
  sl.registerLazySingleton<DailyVerseApiService>(
    () => DailyVerseApiService(),
  );

  // Register platform-specific cache service
  if (kIsWeb) {
    sl.registerLazySingleton<DailyVerseCacheInterface>(
      () => DailyVerseWebCacheService(),
    );
  } else {
    sl.registerLazySingleton<DailyVerseCacheInterface>(
      () => DailyVerseCacheService(),
    );
  }

  sl.registerLazySingleton<DailyVerseRepository>(
    () => DailyVerseRepositoryImpl(
      apiService: sl(),
      cacheService: sl(),
    ),
  );

  // Streak repository for daily verse streak tracking
  sl.registerLazySingleton<StreakRepository>(
    () => StreakRepositoryImpl(sl<SupabaseClient>()),
  );

  sl.registerLazySingleton(() => GetDailyVerse(sl()));
  sl.registerLazySingleton(() => GetCachedVerse(sl()));
  sl.registerLazySingleton(() => GetPreferredLanguage(sl()));
  sl.registerLazySingleton(() => SetPreferredLanguage(sl()));
  sl.registerLazySingleton(() => GetCacheStats(sl()));
  sl.registerLazySingleton(() => ClearVerseCache(sl()));
  sl.registerLazySingleton(() => GetDefaultLanguage(sl()));

  sl.registerFactory(() => DailyVerseBloc(
        getDailyVerse: sl(),
        getCachedVerse: sl(),
        getPreferredLanguage: sl(),
        setPreferredLanguage: sl(),
        getCacheStats: sl(),
        clearVerseCache: sl(),
        getDefaultLanguage: sl(),
        languagePreferenceService: sl(),
        streakRepository: sl(),
      ));

  //! Memory Verses
  // Data Sources
  sl.registerLazySingleton<MemoryVerseLocalDataSource>(
    () => MemoryVerseLocalDataSource(),
  );

  sl.registerLazySingleton<MemoryVerseRemoteDataSource>(
    () => MemoryVerseRemoteDataSource(
      httpService: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<MemoryVerseRepository>(
    () => MemoryVerseRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetDueVerses(sl()));
  sl.registerLazySingleton(() => AddVerseFromDaily(sl()));
  sl.registerLazySingleton(() => AddVerseManually(sl()));
  sl.registerLazySingleton(() => SubmitReview(sl()));
  sl.registerLazySingleton(() => GetStatistics(sl()));
  sl.registerLazySingleton(() => FetchVerseText(sl()));
  sl.registerLazySingleton(() => DeleteVerse(sl()));

  // BLoC
  sl.registerFactory(() => MemoryVerseBloc(
        getDueVerses: sl(),
        addVerseFromDaily: sl(),
        addVerseManually: sl(),
        submitReview: sl(),
        getStatistics: sl(),
        fetchVerseText: sl(),
        deleteVerse: sl(),
      ));

  //! Saved Guides
  sl.registerLazySingleton<StudyGuidesApiService>(
    () => StudyGuidesApiService(),
  );

  sl.registerLazySingleton<SaveGuideApiService>(
    () => SaveGuideApiService(httpClient: sl()),
  );

  // Register Saved Guides Data Sources
  sl.registerLazySingleton<SavedGuidesLocalDataSource>(
    () => SavedGuidesLocalDataSourceImpl(),
  );

  sl.registerLazySingleton<SavedGuidesRemoteDataSource>(
    () => SavedGuidesRemoteDataSourceImpl(
      apiService: sl(),
    ),
  );

  // Register Saved Guides Repository
  sl.registerLazySingleton<SavedGuidesRepository>(
    () => SavedGuidesRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );

  // Register Saved Guides Use Cases
  sl.registerLazySingleton(() => GetSavedGuidesWithSync(repository: sl()));
  sl.registerLazySingleton(() => GetRecentGuidesWithSync(repository: sl()));
  sl.registerLazySingleton(() => ToggleSaveGuideApi(repository: sl()));

  sl.registerFactory(() => UnifiedSavedGuidesBloc(
        getSavedGuidesWithSync: sl(),
        getRecentGuidesWithSync: sl(),
        toggleSaveGuideApi: sl(),
      ));

  //! Feedback
  sl.registerLazySingleton<FeedbackRemoteDataSource>(
    () => FeedbackRemoteDataSourceImpl(supabaseClient: sl()),
  );

  sl.registerLazySingleton<FeedbackRepository>(
    () => FeedbackRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => SubmitFeedbackUseCase(repository: sl()));

  sl.registerFactory(() => FeedbackBloc(submitFeedbackUseCase: sl()));

  //! Home
  sl.registerLazySingleton(() => RecommendedGuidesService());

  // Register Home BLoCs as singletons to maintain state across navigation
  sl.registerLazySingleton(
    () => RecommendedTopicsBloc(
      topicsService: sl(),
      languagePreferenceService: sl(),
      prefs: sl(),
    ),
    dispose: (bloc) => bloc.close(),
  );

  sl.registerLazySingleton(
    () => HomeStudyGenerationBloc(
      generateStudyGuideUseCase: sl(),
    ),
    dispose: (bloc) => bloc.close(),
  );

  sl.registerLazySingleton(
    () => HomeBloc(
      topicsBloc: sl(),
      studyGenerationBloc: sl(),
      languagePreferenceService: sl(),
      learningPathsRepository: sl(),
    ),
    dispose: (bloc) => bloc.close(),
  );

  //! Study Topics
  sl.registerLazySingleton<StudyTopicsRemoteDataSource>(
    () => StudyTopicsRemoteDataSourceImpl(httpService: sl()),
  );

  sl.registerLazySingleton<StudyTopicsRepository>(
    () => StudyTopicsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(() => StudyTopicsBloc(
        repository: sl(),
        languagePreferenceService: sl(),
      ));

  //! Topic Progress Tracking
  sl.registerLazySingleton<TopicProgressRemoteDataSource>(
    () => TopicProgressRemoteDataSourceImpl(httpService: sl()),
  );

  sl.registerLazySingleton<TopicProgressRepository>(
    () => TopicProgressRepositoryImpl(remoteDataSource: sl()),
  );

  //! Learning Paths (Curated Learning Journeys)
  sl.registerLazySingleton<LearningPathsRemoteDataSource>(
    () => LearningPathsRemoteDataSourceImpl(httpService: sl()),
  );

  sl.registerLazySingleton<LearningPathsRepository>(
    () => LearningPathsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(() => LearningPathsBloc(
        repository: sl(),
      ));

  //! Continue Learning (In-Progress Topics)
  sl.registerFactory(() => ContinueLearningBloc(
        repository: sl<TopicProgressRepository>(),
      ));

  //! Onboarding
  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(),
  );

  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetOnboardingState(sl()));
  sl.registerLazySingleton(() => SaveLanguagePreference(sl()));
  sl.registerLazySingleton(() => CompleteOnboarding(sl()));

  sl.registerFactory(() => OnboardingBloc(
        getOnboardingState: sl(),
        saveLanguagePreference: sl(),
        completeOnboarding: sl(),
      ));

  //! User Profile
  sl.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<UserProfileService>(
    () => UserProfileService(
      apiService: sl(),
      authService: sl(),
    ),
  );

  sl.registerLazySingleton(() => GetUserProfile(repository: sl()));
  sl.registerLazySingleton(() => UpdateUserProfile(repository: sl()));
  sl.registerLazySingleton(() => DeleteUserProfile(repository: sl()));

  sl.registerFactory(() => UserProfileBloc(
        getUserProfile: sl(),
        updateUserProfile: sl(),
        deleteUserProfile: sl(),
        repository: sl(),
      ));

  //! Tokens
  registerTokenDependencies(sl);

  //! Subscription
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );

  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton(() => CreateSubscription(sl()));
  sl.registerLazySingleton(() => CancelSubscription(sl()));
  sl.registerLazySingleton(() => ResumeSubscription(sl()));
  sl.registerLazySingleton(() => GetActiveSubscription(sl()));
  sl.registerLazySingleton(() => GetSubscriptionHistory(sl()));
  sl.registerLazySingleton(() => GetInvoices(sl()));

  sl.registerFactory(() => SubscriptionBloc(
        createSubscription: sl(),
        cancelSubscription: sl(),
        resumeSubscription: sl(),
        getActiveSubscription: sl(),
        getSubscriptionHistory: sl(),
        getSubscriptionInvoices: sl(),
      ));

  //! Follow Up Chat
  sl.registerLazySingleton(() => ConversationService(
        httpService: sl(),
      ));

  sl.registerFactory(() => FollowUpChatBloc(
        httpService: sl(),
        conversationService: sl(),
      ));

  //! Notifications
  // Register GoRouter (required by NotificationService)
  sl.registerLazySingleton<GoRouter>(() => AppRouter.router);

  // Register NotificationService first (required by repository)
  sl.registerLazySingleton<NotificationService>(() => NotificationService(
        supabaseClient: sl(),
        router: sl(),
      ));

  sl.registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(
            supabaseClient: sl(),
            notificationService: sl(),
          ));

  sl.registerLazySingleton(
      () => get_preferences_usecase.GetNotificationPreferences(sl()));
  sl.registerLazySingleton(
      () => update_preferences_usecase.UpdateNotificationPreferences(sl()));
  sl.registerLazySingleton(
      () => request_permissions_usecase.RequestNotificationPermissions(sl()));
  sl.registerLazySingleton(
      () => check_permissions_usecase.CheckNotificationPermissions(sl()));

  sl.registerFactory(() => NotificationBloc(
        getPreferences: sl(),
        updatePreferences: sl(),
        requestPermissions: sl(),
        checkPermissions: sl(),
      ));

  //! Voice Buddy
  // Services
  sl.registerLazySingleton(() => SpeechService());
  sl.registerLazySingleton(() => TTSService());

  // Data Source
  sl.registerLazySingleton<VoiceBuddyRemoteDataSource>(
    () => VoiceBuddyRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<VoiceBuddyRepository>(
    () => VoiceBuddyRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  // BLoC
  sl.registerFactory(() => VoicePreferencesBloc(
        repository: sl(),
      ));

  sl.registerFactory(() => VoiceConversationBloc(
        repository: sl(),
        speechService: sl(),
        ttsService: sl(),
        supabaseClient: sl(),
      ));
}
