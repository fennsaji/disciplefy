import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/network_info.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/study_generation/domain/repositories/study_repository.dart';
import '../../features/study_generation/data/repositories/study_repository_impl.dart';
import '../../features/study_generation/domain/usecases/generate_study_guide.dart';
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
import '../../features/daily_verse/domain/repositories/daily_verse_repository.dart';
import '../../features/daily_verse/data/repositories/daily_verse_repository_impl.dart';
import '../../features/daily_verse/domain/usecases/get_daily_verse.dart';
import '../../features/daily_verse/domain/usecases/manage_verse_preferences.dart';
import '../../features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../features/saved_guides/data/services/unified_study_guides_service.dart';
import '../../features/saved_guides/data/services/study_guides_api_service.dart';
import '../../features/saved_guides/presentation/bloc/saved_guides_api_bloc.dart';

final sl = GetIt.instance;

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

  //! Auth
  sl.registerLazySingleton(() => AuthService());
  sl.registerFactory(() => AuthBloc(authService: sl()));

  //! Study Generation
  sl.registerLazySingleton<StudyRepository>(
    () => StudyRepositoryImpl(
      supabaseClient: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton(() => GenerateStudyGuide(sl()));

  sl.registerFactory(() => StudyBloc(generateStudyGuide: sl()));

  //! Settings
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(sharedPreferences: sl()),
  );

  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetSettings(sl()));
  sl.registerLazySingleton(() => UpdateThemeMode(sl()));
  sl.registerLazySingleton(() => GetAppVersion(sl()));

  sl.registerFactory(() => SettingsBloc(
        getSettings: sl(),
        updateThemeMode: sl(),
        getAppVersion: sl(),
        settingsRepository: sl(),
        supabaseClient: sl(),
        authService: sl(),
      ));


  //! Daily Verse
  sl.registerLazySingleton<DailyVerseApiService>(
    () => DailyVerseApiService(httpClient: sl()),
  );

  sl.registerLazySingleton<DailyVerseCacheService>(
    () => DailyVerseCacheService(),
  );

  sl.registerLazySingleton<DailyVerseRepository>(
    () => DailyVerseRepositoryImpl(
      apiService: sl(),
      cacheService: sl(),
    ),
  );

  sl.registerLazySingleton(() => GetDailyVerse(sl()));
  sl.registerLazySingleton(() => GetPreferredLanguage(sl()));
  sl.registerLazySingleton(() => SetPreferredLanguage(sl()));
  sl.registerLazySingleton(() => GetCacheStats(sl()));
  sl.registerLazySingleton(() => ClearVerseCache(sl()));

  sl.registerFactory(() => DailyVerseBloc(
        getDailyVerse: sl(),
        getPreferredLanguage: sl(),
        setPreferredLanguage: sl(),
        getCacheStats: sl(),
        clearVerseCache: sl(),
      ));

  //! Saved Guides
  sl.registerLazySingleton<StudyGuidesApiService>(
    () => StudyGuidesApiService(),
  );

  sl.registerLazySingleton<UnifiedStudyGuidesService>(
    () => UnifiedStudyGuidesService(apiService: sl()),
  );

  sl.registerFactory(() => SavedGuidesApiBloc(
        unifiedService: sl(),
      ));
}