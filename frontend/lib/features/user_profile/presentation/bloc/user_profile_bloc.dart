import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/usecases/get_user_profile.dart';
import '../../domain/usecases/update_user_profile.dart';
import '../../domain/usecases/delete_user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import 'user_profile_event.dart';
import 'user_profile_state.dart';
import '../../../../core/utils/logger.dart';

/// BLoC for managing user profile state
/// Handles profile CRUD operations with proper error handling
/// Uses shared error handling utility to reduce code duplication
class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final GetUserProfile _getUserProfile;
  final UpdateUserProfile _updateUserProfile;
  final DeleteUserProfile _deleteUserProfile;
  final UserProfileRepository _repository;

  /// Creates a UserProfileBloc with required dependencies
  UserProfileBloc({
    required GetUserProfile getUserProfile,
    required UpdateUserProfile updateUserProfile,
    required DeleteUserProfile deleteUserProfile,
    required UserProfileRepository repository,
  })  : _getUserProfile = getUserProfile,
        _updateUserProfile = updateUserProfile,
        _deleteUserProfile = deleteUserProfile,
        _repository = repository,
        super(UserProfileInitial()) {
    on<LoadUserProfileEvent>(_onLoadUserProfile);
    on<UpdateUserProfileEvent>(_onUpdateUserProfile);
    on<DeleteUserProfileEvent>(_onDeleteUserProfile);
    on<UpdateLanguagePreferenceEvent>(_onUpdateLanguagePreference);
    on<UpdateThemePreferenceEvent>(_onUpdateThemePreference);
    on<CheckAdminStatusEvent>(_onCheckAdminStatus);
  }

  /// Handles loading user profile
  Future<void> _onLoadUserProfile(
    LoadUserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(UserProfileLoading());

    final result = await _getUserProfile(
      GetUserProfileParams(userId: event.userId),
    );

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => UserProfileError(
        message: message,
        errorCode: errorCode,
      ),
      onSuccess: (dynamic profile) {
        if (profile != null) {
          emit(UserProfileLoaded(profile: profile));
          // Check admin status
          add(CheckAdminStatusEvent(userId: event.userId));
        } else {
          emit(UserProfileEmpty(userId: event.userId));
        }
      },
      operationName: 'load user profile',
    );
  }

  /// Handles updating user profile
  Future<void> _onUpdateUserProfile(
    UpdateUserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(UserProfileLoading());

    final result = await _updateUserProfile(
      UpdateUserProfileParams(profile: event.profile),
    );

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => UserProfileError(
        message: message,
        errorCode: errorCode,
      ),
      onSuccess: (_) =>
          emit(UserProfileUpdateSuccess(updatedProfile: event.profile)),
      operationName: 'update user profile',
    );
  }

  /// Handles deleting user profile
  Future<void> _onDeleteUserProfile(
    DeleteUserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(UserProfileLoading());

    final result = await _deleteUserProfile(
      DeleteUserProfileParams(userId: event.userId),
    );

    ErrorHandler.handleEitherResult(
      result: result,
      emit: emit,
      createErrorState: (message, errorCode) => UserProfileError(
        message: message,
        errorCode: errorCode,
      ),
      onSuccess: (_) => emit(UserProfileDeleteSuccess()),
      operationName: 'delete user profile',
    );
  }

  /// Handles updating language preference
  Future<void> _onUpdateLanguagePreference(
    UpdateLanguagePreferenceEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    await ErrorHandler.wrapAsyncOperation(
      operation: () async {
        // Invalidate profile cache before updating
        final authStateProvider = sl<AuthStateProvider>();
        authStateProvider.invalidateProfileCache();
        Logger.debug(
            '📄 [USER_PROFILE_BLOC] Profile cache invalidated for language update');

        await _repository.updateLanguagePreference(
          event.userId,
          event.languageCode,
        );
        emit(LanguagePreferenceUpdated(newLanguage: event.languageCode));

        // Reload profile to get updated data
        add(LoadUserProfileEvent(userId: event.userId));
      },
      emit: emit,
      createErrorState: (message, errorCode) => UserProfileError(
        message: message,
        errorCode: errorCode ?? 'LANGUAGE_UPDATE_ERROR',
      ),
      operationName: 'update language preference',
    );
  }

  /// Handles updating theme preference
  Future<void> _onUpdateThemePreference(
    UpdateThemePreferenceEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    await ErrorHandler.wrapAsyncOperation(
      operation: () async {
        // Invalidate profile cache before updating
        final authStateProvider = sl<AuthStateProvider>();
        authStateProvider.invalidateProfileCache();
        Logger.debug(
            '📄 [USER_PROFILE_BLOC] Profile cache invalidated for theme update');

        await _repository.updateThemePreference(event.userId, event.theme);
        emit(ThemePreferenceUpdated(newTheme: event.theme));

        // Reload profile to get updated data
        add(LoadUserProfileEvent(userId: event.userId));
      },
      emit: emit,
      createErrorState: (message, errorCode) => UserProfileError(
        message: message,
        errorCode: errorCode ?? 'THEME_UPDATE_ERROR',
      ),
      operationName: 'update theme preference',
    );
  }

  /// Handles checking admin status
  Future<void> _onCheckAdminStatus(
    CheckAdminStatusEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    try {
      final isAdmin = await _repository.isUserAdmin(event.userId);

      // Update current state if it's UserProfileLoaded
      if (state is UserProfileLoaded) {
        final currentState = state as UserProfileLoaded;
        emit(currentState.copyWith(isAdmin: isAdmin));
      }
    } catch (e) {
      // Don't emit error for admin check failure, silently ignore
      // This prevents disrupting the main profile loading flow
      // Using shared error handler for consistent logging (silent mode)
      Logger.error('🚨 [ERROR] check admin status failed: $e');
    }
  }
}
