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
import '../../features/saved_guides/domain/repositories/saved_guides_repository.dart';
import '../../features/saved_guides/data/repositories/saved_guides_repository_impl.dart';
import '../../features/saved_guides/data/datasources/saved_guides_local_data_source.dart';
import '../../features/saved_guides/domain/usecases/get_saved_guides.dart';
import '../../features/saved_guides/domain/usecases/get_recent_guides.dart';
import '../../features/saved_guides/domain/usecases/save_guide.dart';
import '../../features/saved_guides/domain/usecases/remove_guide.dart';
import '../../features/saved_guides/domain/usecases/add_to_recent.dart';
import '../../features/saved_guides/presentation/bloc/saved_guides_bloc.dart';

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
      ));

  //! Saved Guides
  sl.registerLazySingleton<SavedGuidesLocalDataSource>(
    () => SavedGuidesLocalDataSourceImpl(),
  );

  sl.registerLazySingleton<SavedGuidesRepository>(
    () => SavedGuidesRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetSavedGuides(sl()));
  sl.registerLazySingleton(() => GetRecentGuides(sl()));
  sl.registerLazySingleton(() => SaveGuide(sl()));
  sl.registerLazySingleton(() => RemoveGuide(sl()));
  sl.registerLazySingleton(() => AddToRecent(sl()));

  sl.registerFactory(() => SavedGuidesBloc(
        getSavedGuides: sl(),
        getRecentGuides: sl(),
        saveGuide: sl(),
        removeGuide: sl(),
        addToRecent: sl(),
        repository: sl(),
      ));
}