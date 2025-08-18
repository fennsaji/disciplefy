import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../network/network_info.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
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
import '../services/theme_service.dart';
import '../services/auth_state_provider.dart';
import '../services/language_preference_service.dart';
import '../services/http_service.dart';
import '../../features/user_profile/data/services/user_profile_api_service.dart';

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

  // Register ThemeService
  sl.registerLazySingleton(() => ThemeService());

  // Register HttpService
  sl.registerLazySingleton(() => HttpService(httpClient: sl()));

  // Register User Profile API Service
  sl.registerLazySingleton(() => UserProfileApiService(
        httpService: sl<HttpService>(),
      ));

  // Register Language Preference Service
  sl.registerLazySingleton(() => LanguagePreferenceService(
        prefs: sl(),
        authService: sl(),
        authStateProvider: sl(),
        userProfileService: sl(),
      ));

  //! Auth
  sl.registerLazySingleton(() => AuthService());
  sl.registerFactory(() => AuthBloc(authService: sl()));

  // Register AuthStateProvider as singleton for consistent state across screens
  sl.registerLazySingleton(() => AuthStateProvider());

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

  sl.registerLazySingleton(() => SettingsBloc(
        getSettings: sl(),
        updateThemeMode: sl(),
        getAppVersion: sl(),
        settingsRepository: sl(),
        themeService: sl(),
        languagePreferenceService: sl(),
      ));

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

  sl.registerFactory(() => HomeBloc(
        topicsBloc: sl(),
        studyGenerationBloc: sl(),
      ));

  sl.registerFactory(() => RecommendedTopicsBloc(
        topicsService: sl(),
      ));

  sl.registerFactory(() => HomeStudyGenerationBloc(
        generateStudyGuideUseCase: sl(),
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
}
