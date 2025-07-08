import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../network/network_info.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/study_generation/domain/repositories/study_repository.dart';
import '../../features/study_generation/data/repositories/study_repository_impl.dart';
import '../../features/study_generation/domain/usecases/generate_study_guide.dart';
import '../../features/study_generation/presentation/bloc/study_bloc.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  //! Core
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => Supabase.instance.client);
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl()),
  );

  //! Auth
  sl.registerLazySingleton(() => AuthService());

  //! Study Generation
  sl.registerLazySingleton<StudyRepository>(
    () => StudyRepositoryImpl(
      supabaseClient: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton(() => GenerateStudyGuide(sl()));

  sl.registerFactory(() => StudyBloc(generateStudyGuide: sl()));
}