import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/study_generation/presentation/bloc/study_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();
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
    
    runApp(const DisciplefyBibleStudyApp());
  } catch (e) {
    runApp(const ErrorApp());
  }
}

class DisciplefyBibleStudyApp extends StatelessWidget {
  const DisciplefyBibleStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<StudyBloc>(
          create: (context) => sl<StudyBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Disciplefy Bible Study',
        debugShowCheckedModeBanner: false,
        
        // Theming
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        
        // Localization
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        
        // Navigation
        routerConfig: AppRouter.router,
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disciplefy Bible Study - Error',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
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
}