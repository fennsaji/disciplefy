import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/update_theme_mode.dart' as use_case;
import '../../domain/usecases/get_app_version.dart';
import '../../domain/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetSettings getSettings;
  final use_case.UpdateThemeMode updateThemeMode;
  final GetAppVersion getAppVersion;
  final SettingsRepository settingsRepository;
  final SupabaseClient supabaseClient;

  SettingsBloc({
    required this.getSettings,
    required this.updateThemeMode,
    required this.getAppVersion,
    required this.settingsRepository,
    required this.supabaseClient,
  }) : super(SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<UpdateLanguage>(_onUpdateLanguage);
    on<ToggleNotifications>(_onToggleNotifications);
    on<LoadAppVersion>(_onLoadAppVersion);
    on<ClearAllSettings>(_onClearAllSettings);
    on<LogoutUser>(_onLogoutUser);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    final result = await getSettings(NoParams());
    result.fold(
      (failure) => emit(SettingsError(message: failure.message)),
      (settings) => emit(SettingsLoaded(settings: settings)),
    );
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      emit(SettingsLoading());

      final result = await updateThemeMode(
        use_case.UpdateThemeModeParams(themeMode: event.themeMode),
      );

      result.fold(
        (failure) => emit(SettingsError(message: failure.message)),
        (_) {
          final updatedSettings = currentState.settings.copyWith(
            themeMode: event.themeMode,
          );
          emit(SettingsLoaded(settings: updatedSettings));
          if (!emit.isDone) {
            emit(const SettingsUpdateSuccess(message: 'Theme updated successfully'));
          }
        },
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

      final result = await settingsRepository.updateLanguage(event.language);

      result.fold(
        (failure) => emit(SettingsError(message: failure.message)),
        (_) {
          final updatedSettings = currentState.settings.copyWith(
            language: event.language,
          );
          emit(SettingsLoaded(settings: updatedSettings));
          if (!emit.isDone) {
            emit(const SettingsUpdateSuccess(message: 'Language updated successfully'));
          }
        },
      );
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

      result.fold(
        (failure) => emit(SettingsError(message: failure.message)),
        (_) {
          emit(SettingsLoaded(settings: updatedSettings));
          if (!emit.isDone) {
            emit(SettingsUpdateSuccess(
              message: event.enabled 
                  ? 'Notifications enabled' 
                  : 'Notifications disabled',
            ));
          }
        },
      );
    }
  }

  Future<void> _onLoadAppVersion(
    LoadAppVersion event,
    Emitter<SettingsState> emit,
  ) async {
    final result = await getAppVersion(NoParams());
    result.fold(
      (failure) => emit(SettingsError(message: failure.message)),
      (version) {
        if (state is SettingsLoaded) {
          final currentState = state as SettingsLoaded;
          final updatedSettings = currentState.settings.copyWith(
            appVersion: version,
          );
          emit(SettingsLoaded(settings: updatedSettings));
        }
      },
    );
  }

  Future<void> _onClearAllSettings(
    ClearAllSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    final result = await settingsRepository.clearAllSettings();

    result.fold(
      (failure) => emit(SettingsError(message: failure.message)),
      (_) => emit(const SettingsUpdateSuccess(message: 'All settings cleared')),
    );
  }

  Future<void> _onLogoutUser(
    LogoutUser event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await supabaseClient.auth.signOut();
      await settingsRepository.clearAllSettings();
      if (!emit.isDone) {
        emit(LogoutSuccess());
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(LogoutError(message: 'Logout failed: ${e.toString()}'));
      }
    }
  }
}