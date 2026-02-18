import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/models/app_language.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/update_theme_mode.dart';
import '../../domain/usecases/get_app_version.dart';
import '../../domain/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';
import '../../../../core/utils/logger.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetSettings getSettings;
  final UpdateThemeMode updateThemeMode;
  final GetAppVersion getAppVersion;
  final SettingsRepository settingsRepository;
  final ThemeService themeService;
  final LanguagePreferenceService languagePreferenceService;

  bool _hasInitialized = false;

  SettingsBloc({
    required this.getSettings,
    required this.updateThemeMode,
    required this.getAppVersion,
    required this.settingsRepository,
    required this.themeService,
    required this.languagePreferenceService,
  }) : super(SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<UpdateLanguage>(_onUpdateLanguage);
    on<ToggleNotifications>(_onToggleNotifications);
    on<LoadAppVersion>(_onLoadAppVersion);
    on<ClearAllSettings>(_onClearAllSettings);

    // Auto-initialize settings once when bloc is created
    if (!_hasInitialized) {
      _hasInitialized = true;
      add(LoadSettings());
    }
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    try {
      final result = await getSettings(NoParams());

      await result.fold(
        (failure) async => emit(SettingsError(message: failure.message)),
        (settings) async {
          // Check if we need to sync language preference from LanguagePreferenceService
          try {
            final currentLanguage =
                await languagePreferenceService.getSelectedLanguage();

            // If settings language differs from LanguagePreferenceService, sync it
            if (settings.language != currentLanguage.code) {
              Logger.debug(
                  'Settings language (${settings.language}) differs from LanguagePreferenceService (${currentLanguage.code}). Syncing...');

              // Update settings repository with the correct language
              await settingsRepository.updateLanguage(currentLanguage.code);

              // Create updated settings object
              final syncedSettings =
                  settings.copyWith(language: currentLanguage.code);
              if (!emit.isDone) {
                emit(SettingsLoaded(settings: syncedSettings));
              }
              return;
            }
          } catch (e) {
            Logger.debug('Error syncing language preference: $e');
            // Continue with original settings if sync fails
          }

          if (!emit.isDone) {
            emit(SettingsLoaded(settings: settings));
          }
        },
      );
    } catch (e) {
      Logger.debug('Error in _onLoadSettings: $e');
      if (!emit.isDone) {
        emit(SettingsError(message: 'Failed to load settings: $e'));
      }
    }
  }

  Future<void> _onThemeModeChanged(
    ThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    Logger.debug(
        'SettingsBloc: ThemeModeChanged event received - New theme: ${event.themeMode.mode}');
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      emit(SettingsLoading());

      final result = await updateThemeMode(
        UpdateThemeModeParams(themeMode: event.themeMode),
      );

      ErrorHandler.handleEitherResult(
        result: result,
        emit: emit,
        createErrorState: (message, errorCode) =>
            SettingsError(message: message),
        onSuccess: (_) {
          // Update settings with new theme mode directly
          final updatedSettings = currentState.settings.copyWith(
            themeMode: event.themeMode,
          );

          // Update the global theme service directly without delay
          themeService.updateTheme(event.themeMode);

          // Emit loaded state with updated settings (no success message needed)
          emit(SettingsLoaded(settings: updatedSettings));
        },
        operationName: 'update theme mode',
      );
    }
  }

  Future<void> _onUpdateLanguage(
    UpdateLanguage event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      emit(SettingsLoading());

      try {
        // Update local settings first
        final result = await settingsRepository.updateLanguage(event.language);

        await result.fold(
          (failure) => throw Exception(failure.message),
          (_) async {
            // Convert language code to AppLanguage and sync with unified service
            final appLanguage = AppLanguage.fromCode(event.language);
            await languagePreferenceService.saveLanguagePreference(appLanguage);
            await languagePreferenceService.syncWithProfile();

            final updatedSettings = currentState.settings.copyWith(
              language: event.language,
            );
            emit(SettingsLoaded(settings: updatedSettings));
          },
        );
      } catch (e) {
        Logger.debug('Error updating language: $e');
        emit(SettingsError(message: 'Failed to update language: $e'));
      }
    }
  }

  Future<void> _onToggleNotifications(
    ToggleNotifications event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      final updatedSettings = currentState.settings.copyWith(
        notificationsEnabled: event.enabled,
      );

      final result = await settingsRepository.saveSettings(updatedSettings);

      ErrorHandler.handleEitherResult(
        result: result,
        emit: emit,
        createErrorState: (message, errorCode) =>
            SettingsError(message: message),
        onSuccess: (_) {
          emit(SettingsLoaded(settings: updatedSettings));
        },
        operationName: 'toggle notifications',
      );
    }
  }

  Future<void> _onLoadAppVersion(
    LoadAppVersion event,
    Emitter<SettingsState> emit,
  ) async {
    final result = await getAppVersion(NoParams());

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => SettingsError(message: message),
      onSuccess: (dynamic version) {
        if (state is SettingsLoaded) {
          final currentState = state as SettingsLoaded;
          final updatedSettings = currentState.settings.copyWith(
            appVersion: version,
          );
          emit(SettingsLoaded(settings: updatedSettings));
        }
      },
      operationName: 'load app version',
    );
  }

  Future<void> _onClearAllSettings(
    ClearAllSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    final result = await settingsRepository.clearAllSettings();

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => SettingsError(message: message),
      onSuccess: (_) =>
          emit(const SettingsUpdateSuccess(message: 'All settings cleared')),
      operationName: 'clear all settings',
    );
  }
}
