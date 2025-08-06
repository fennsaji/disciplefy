import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/http_service.dart';
import '../../../user_profile/data/services/user_profile_service.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../data/services/auth_service.dart';
import '../../domain/entities/auth_params.dart';
import '../../domain/exceptions/auth_exceptions.dart' as auth_exceptions;
import '../../domain/usecases/clear_user_data_usecase.dart';
import '../../domain/utils/auth_validator.dart';
import 'auth_event.dart';
import 'auth_state.dart' as auth_states;

/// Authentication BLoC managing user authentication state
/// Follows Clean Architecture principles with proper separation of concerns
///
/// Features:
/// - Exponential backoff retry strategy for network failures
/// - Comprehensive error recovery mechanisms
/// - Centralized authentication validation
class AuthBloc extends Bloc<AuthEvent, auth_states.AuthState> {
  final AuthService _authService;
  final UserProfileService _userProfileService;
  final ClearUserDataUseCase _clearUserDataUseCase;
  late final StreamSubscription<AuthState> _authStateSubscription;
  late final StreamSubscription<String> _httpAuthFailureSubscription;

  // Error recovery configuration
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(seconds: 30);

  AuthBloc({
    required AuthService authService,
    UserProfileService? userProfileService,
    ClearUserDataUseCase? clearUserDataUseCase,
  })  : _authService = authService,
        _userProfileService = userProfileService ?? UserProfileService(),
        _clearUserDataUseCase = clearUserDataUseCase ?? ClearUserDataUseCase(),
        super(const auth_states.AuthInitialState()) {
    // Register event handlers
    on<AuthInitializeRequested>(_onAuthInitialize);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<GoogleOAuthCallbackRequested>(_onGoogleOAuthCallback);
    on<AnonymousSignInRequested>(_onAnonymousSignIn);
    on<SessionCheckRequested>(_onSessionCheck);
    on<SignOutRequested>(_onSignOut);
    on<AuthStateChanged>(_onAuthStateChanged);
    on<DeleteAccountRequested>(_onDeleteAccount);
    on<TokenRefreshFailed>(_onTokenRefreshFailed);
    on<ForceLogoutRequested>(_onForceLogout);
    on<UpdateUserProfileRequested>(_onUpdateUserProfile);

    // Initialize authentication state
    add(const AuthInitializeRequested());

    // Listen to authentication state changes from Supabase
    _authStateSubscription = _authService.authStateChanges.listen(
      (supabaseAuthState) {
        add(AuthStateChanged(supabaseAuthState));
      },
    );

    // Listen to HTTP authentication failures
    _httpAuthFailureSubscription = HttpService.authFailureStream.listen(
      (reason) {
        add(ForceLogoutRequested(reason: reason));
      },
    );
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    _httpAuthFailureSubscription.cancel();
    _authService.dispose();
    return super.close();
  }

  /// Initializes authentication state by checking current session
  Future<void> _onAuthInitialize(
    AuthInitializeRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(const auth_states.AuthLoadingState());

      // Check if user is already authenticated (Supabase)
      final supabaseUser = _authService.currentUser;
      if (supabaseUser != null) {
        // Load user profile data for Supabase users
        final profile = await _userProfileService.getUserProfile(supabaseUser.id);

        emit(auth_states.AuthenticatedState(
          user: supabaseUser,
          profile: profile,
          isAnonymous: supabaseUser.isAnonymous,
        ));
        return;
      }

      // Check for anonymous session using async method
      final isAuthenticated = await _authService.isAuthenticatedAsync();
      if (isAuthenticated) {
        // Create mock user for anonymous session
        final user = _createAnonymousUser();

        emit(auth_states.AuthenticatedState(
          user: user,
          isAnonymous: true,
        ));
      } else {
        emit(const auth_states.UnauthenticatedState());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auth initialization error: $e');
      }
      emit(const auth_states.AuthErrorState(message: 'Failed to initialize authentication'));
    }
  }

  /// Handles Google sign-in flow with error recovery
  Future<void> _onGoogleSignIn(
    GoogleSignInRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    await _retryWithExponentialBackoff(
      operation: () async {
        emit(const auth_states.AuthLoadingState());

        // Attempt Google sign-in
        final success = await _authService.signInWithGoogle();

        // REFACTORED: Use centralized authentication validation
        final validationResult = AuthValidator.validateAuthenticationSuccess(
          success: success,
          currentUser: _authService.currentUser,
          operationName: 'Google Sign-In',
        );

        if (validationResult.isSuccess) {
          final user = validationResult.user!;

          // Create or update user profile with retry
          await _retryOperation(() => _userProfileService.upsertUserProfile(
                userId: user.id,
                languagePreference: 'en', // Default language
              ));

          // Load user profile data with retry
          final profile = await _retryOperation(() => _userProfileService.getUserProfile(user.id));

          emit(auth_states.AuthenticatedState(
            user: user,
            profile: profile,
            isAnonymous: false,
          ));
        } else {
          // Handle validation failure
          final errorMessage = validationResult.errorMessage ?? 'Google sign-in failed';
          throw auth_exceptions.AuthenticationFailedException(errorMessage);
        }
      },
      onError: (e) => emit(_mapExceptionToErrorState(e)),
      operationName: 'Google Sign-In',
    );
  }

  /// Handles Google OAuth callback with authorization code and error recovery
  Future<void> _onGoogleOAuthCallback(
    GoogleOAuthCallbackRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    await _retryWithExponentialBackoff(
      operation: () async {
        if (kDebugMode) {
          print('🔐 [AUTH BLOC] 🚀 Starting Google OAuth callback processing...');
        }
        emit(const auth_states.AuthLoadingState());

        if (kDebugMode) {
          print('🔐 [AUTH BLOC] - Code: ${event.code.substring(0, 20)}...');
          print('🔐 [AUTH BLOC] - State: ${event.state}');
        }

        // Process the OAuth callback using AuthService with retry
        if (kDebugMode) {
          print('🔐 [AUTH BLOC] 📞 Calling _authService.processGoogleOAuthCallback...');
        }
        final success = await _retryOperation(() => _authService.processGoogleOAuthCallback(
              GoogleOAuthCallbackParams(
                code: event.code,
                state: event.state,
              ),
            ));

        if (kDebugMode) {
          print('🔐 [AUTH BLOC] 📊 OAuth callback result: $success');
          print('🔐 [AUTH BLOC] 📊 _authService.isAuthenticated: ${_authService.isAuthenticated}');
        }

        // REFACTORED: Use centralized authentication validation
        final validationResult = AuthValidator.validateAuthenticationSuccess(
          success: success,
          currentUser: _authService.currentUser,
          operationName: 'Google OAuth Callback',
        );

        if (validationResult.isSuccess) {
          final user = validationResult.user!;
          if (kDebugMode) {
            print('🔐 [AUTH BLOC] 👤 Retrieved user: ${user.id} (${user.email ?? "Anonymous"})');
            print('🔐 [AUTH BLOC] 👤 User isAnonymous: ${user.isAnonymous}');
          }

          // Load user profile data with retry
          if (kDebugMode) {
            print('🔐 [AUTH BLOC] 📄 Loading user profile...');
          }
          final profile = await _retryOperation(() => _userProfileService.getUserProfile(user.id));
          if (kDebugMode) {
            print('🔐 [AUTH BLOC] 📄 Profile loaded: ${profile != null ? "✅" : "❌"}');
          }

          if (kDebugMode) {
            print('🔐 [AUTH BLOC] ✅ Emitting AuthenticatedState...');
          }
          emit(auth_states.AuthenticatedState(
            user: user,
            isAnonymous: user.isAnonymous,
            profile: profile,
          ));

          if (kDebugMode) {
            print('🔐 [AUTH BLOC] ✅ AuthenticatedState emitted successfully');
          }
        } else {
          // Handle validation failure
          final errorMessage = validationResult.errorMessage ?? 'OAuth callback processing failed';
          if (kDebugMode) {
            print('🔐 [AUTH BLOC] ❌ $errorMessage');
          }
          throw auth_exceptions.AuthenticationFailedException(errorMessage);
        }
      },
      onError: (e) => emit(_mapExceptionToErrorState(e)),
      operationName: 'Google OAuth Callback',
    );
  }

  /// Handles anonymous sign-in flow with error recovery
  Future<void> _onAnonymousSignIn(
    AnonymousSignInRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    await _retryWithExponentialBackoff(
      operation: () async {
        emit(const auth_states.AuthLoadingState());

        // Attempt anonymous sign-in with retry
        final success = await _retryOperation(() => _authService.signInAnonymously());

        if (success) {
          // Check authentication status using async method with retry
          final isAuthenticated = await _retryOperation(() => _authService.isAuthenticatedAsync());

          if (isAuthenticated) {
            // For anonymous users, create a mock user object since Supabase user is null
            final user = _authService.currentUser ?? _createAnonymousUser();

            emit(auth_states.AuthenticatedState(
              user: user,
              isAnonymous: true,
            ));
          } else {
            throw const auth_exceptions.AuthenticationFailedException('Anonymous sign-in failed');
          }
        } else {
          throw const auth_exceptions.AuthenticationFailedException('Anonymous sign-in failed');
        }
      },
      onError: (e) => emit(_mapExceptionToErrorState(e)),
      operationName: 'Anonymous Sign-In',
    );
  }

  /// Handles session check (used for OAuth callbacks)
  Future<void> _onSessionCheck(
    SessionCheckRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('🔐 [AUTH BLOC] 📊 Checking current session state...');
      }

      // Check current Supabase session
      final currentUser = _authService.currentUser;
      final currentSession = Supabase.instance.client.auth.currentSession;

      if (currentUser != null && currentSession != null) {
        if (kDebugMode) {
          print('🔐 [AUTH BLOC] ✅ Valid session found: ${currentUser.email ?? currentUser.id}');
        }

        // Load user profile if not anonymous
        Map<String, dynamic>? profile;
        if (!currentUser.isAnonymous) {
          profile = await _userProfileService.getUserProfile(currentUser.id);
        }

        emit(auth_states.AuthenticatedState(
          user: currentUser,
          profile: profile,
          isAnonymous: currentUser.isAnonymous,
        ));
      } else {
        if (kDebugMode) {
          print('🔐 [AUTH BLOC] ❌ No valid session found');
        }
        emit(const auth_states.UnauthenticatedState());
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH BLOC] ❌ Session check error: $e');
      }
      emit(auth_states.AuthErrorState(message: 'Session check failed: ${e.toString()}'));
    }
  }

  /// Handles sign-out flow
  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(const auth_states.AuthLoadingState());

      // Clear all user data including authentication and storage
      await _clearUserDataUseCase.execute();

      emit(const auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('Sign-out error: $e');
      }
      emit(const auth_states.AuthErrorState(message: 'Failed to sign out'));
    }
  }

  /// Handles authentication state changes from Supabase
  Future<void> _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      final authState = event.supabaseAuthState;

      if (authState.event == AuthChangeEvent.signedIn) {
        final user = authState.session?.user;
        if (user != null) {
          // Load user profile if authenticated (not anonymous)
          final profile = user.isAnonymous ? null : await _userProfileService.getUserProfile(user.id);

          emit(auth_states.AuthenticatedState(
            user: user,
            profile: profile,
            isAnonymous: user.isAnonymous,
          ));
        }
      } else if (authState.event == AuthChangeEvent.signedOut) {
        // Check if we have an anonymous session before signing out completely
        final isAuthenticated = await _authService.isAuthenticatedAsync();
        if (isAuthenticated) {
          // Keep anonymous session active
          final user = _createAnonymousUser();
          emit(auth_states.AuthenticatedState(
            user: user,
            isAnonymous: true,
          ));
        } else {
          emit(const auth_states.UnauthenticatedState());
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auth state change error: $e');
      }
      // For flow state errors and similar, just ignore and don't change state
      // This prevents Supabase OAuth recovery errors from affecting anonymous sessions
      if (e.toString().contains('flow_state_not_found') || e.toString().contains('invalid flow state')) {
        if (kDebugMode) {
          print('Ignoring Supabase flow state error - likely expired OAuth session');
        }
        return;
      }
      // Don't emit error state for auth state changes to avoid loops
    }
  }

  /// Handles account deletion
  Future<void> _onDeleteAccount(
    DeleteAccountRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(const auth_states.AuthLoadingState());

      // Delete account and all associated data
      await _authService.deleteAccount();

      emit(const auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('Delete account error: $e');
      }
      emit(const auth_states.AuthErrorState(message: 'Failed to delete account'));
    }
  }

  /// Checks if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return false;
      }
      return await _userProfileService.isCurrentUserAdmin(user.id);
    } catch (e) {
      if (kDebugMode) {
        print('Admin check error: $e');
      }
      return false;
    }
  }

  /// Handles token refresh failure
  Future<void> _onTokenRefreshFailed(
    TokenRefreshFailed event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('Token refresh failed: ${event.reason}');
      }

      // Clear all authentication data using UseCase
      await _clearUserDataUseCase.execute();

      // Emit unauthenticated state
      emit(const auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('Error handling token refresh failure: $e');
      }
      // Still emit unauthenticated state even if cleanup fails
      emit(const auth_states.UnauthenticatedState());
    }
  }

  /// Handles force logout request
  Future<void> _onForceLogout(
    ForceLogoutRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print('Force logout requested: ${event.reason}');
      }

      emit(const auth_states.AuthLoadingState());

      // Clear all authentication data using UseCase
      await _clearUserDataUseCase.execute();

      // Emit unauthenticated state
      emit(const auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('Error during force logout: $e');
      }
      // Still emit unauthenticated state even if cleanup fails
      emit(const auth_states.UnauthenticatedState());
    }
  }

  // Note: Data cleanup is now handled by ClearUserDataUseCase

  /// Helper method to map authentication exceptions to error states
  /// Reduces code duplication in event handlers
  auth_states.AuthErrorState _mapExceptionToErrorState(Exception exception) {
    if (exception is auth_exceptions.OAuthCancelledException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else if (exception is auth_exceptions.RateLimitException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else if (exception is auth_exceptions.NetworkException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else if (exception is auth_exceptions.CsrfValidationException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else if (exception is auth_exceptions.InvalidRequestException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else if (exception is auth_exceptions.AuthConfigException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else if (exception is auth_exceptions.AuthException) {
      return auth_states.AuthErrorState(
        message: exception.message,
        severity: exception.severity,
      );
    } else {
      if (kDebugMode) {
        print('Unexpected authentication exception: $exception');
      }
      return const auth_states.AuthErrorState(
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Handles user profile updates
  Future<void> _onUpdateUserProfile(
    UpdateUserProfileRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        emit(const auth_states.AuthErrorState(message: 'User not authenticated'));
        return;
      }

      await _userProfileService.upsertUserProfile(
        userId: user.id,
        languagePreference: event.languagePreference,
        themePreference: event.themePreference,
      );

      // Refresh auth state to get updated profile
      final profile = await _userProfileService.getUserProfile(user.id);

      emit(auth_states.AuthenticatedState(
        user: user,
        profile: profile,
        isAnonymous: user.isAnonymous,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('Profile update error: $e');
      }
      emit(const auth_states.AuthErrorState(message: 'Failed to update profile'));
    }
  }

  /// Creates a mock User object for anonymous sessions
  User _createAnonymousUser() {
    // Create a minimal User object for anonymous sessions
    // This is needed because the AuthenticatedState expects a User object
    return User(
      id: 'anonymous_user',
      appMetadata: const {},
      userMetadata: const {'is_anonymous': true},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: true,
    );
  }

  // ===== ERROR RECOVERY MECHANISMS =====

  /// Retries an operation with exponential backoff for network-related failures
  ///
  /// Features:
  /// - Exponential backoff with jitter to prevent thundering herd
  /// - Maximum retry attempts and delay limits
  /// - Intelligent error categorization (retryable vs non-retryable)
  /// - Comprehensive logging for debugging
  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempt = 0;
    Duration delay = _baseRetryDelay;

    while (attempt < _maxRetryAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (kDebugMode) {
          print('🔄 [AUTH RETRY] Attempt $attempt failed: $e');
        }

        // Check if error is retryable
        if (!_isRetryableError(e) || attempt >= _maxRetryAttempts) {
          if (kDebugMode) {
            print('🚫 [AUTH RETRY] Error not retryable or max attempts reached');
          }
          rethrow;
        }

        // Calculate delay with exponential backoff and jitter
        final jitter = Random().nextDouble() * 0.5; // 0-50% jitter
        final actualDelay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * (1 + jitter)).round(),
            _maxRetryDelay.inMilliseconds,
          ),
        );

        if (kDebugMode) {
          print('🕐 [AUTH RETRY] Retrying in ${actualDelay.inMilliseconds}ms...');
        }

        await Future.delayed(actualDelay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 2).round());
      }
    }

    throw Exception('Retry limit exceeded');
  }

  /// Wrapper for operations that need retry logic with error handling
  Future<void> _retryWithExponentialBackoff({
    required Future<void> Function() operation,
    required void Function(Exception) onError,
    required String operationName,
  }) async {
    try {
      await _retryOperation(operation);
    } on Exception catch (e) {
      if (kDebugMode) {
        print('🚨 [AUTH RECOVERY] $operationName failed after all retries: $e');
      }
      onError(e);
    }
  }

  /// Determines if an error is retryable based on its type and characteristics
  bool _isRetryableError(dynamic error) {
    // Network-related errors that can be retried
    if (error is auth_exceptions.NetworkException) {
      return true;
    }

    // Rate limiting should be retried with backoff
    if (error is auth_exceptions.RateLimitException) {
      return true;
    }

    // Check error message for network-related issues
    final errorString = error.toString().toLowerCase();

    // Common network error indicators
    final networkErrorPatterns = [
      'network',
      'connection',
      'timeout',
      'unreachable',
      'dns',
      'socket',
      'http exception',
      'failed host lookup',
      'connection refused',
      'connection timed out',
      'no internet',
      'network unreachable',
    ];

    for (final pattern in networkErrorPatterns) {
      if (errorString.contains(pattern)) {
        return true;
      }
    }

    // Server errors (5xx) are generally retryable
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    // Non-retryable errors
    if (error is auth_exceptions.OAuthCancelledException ||
        error is auth_exceptions.AuthConfigException ||
        error is auth_exceptions.CsrfValidationException ||
        error is auth_exceptions.InvalidRequestException) {
      return false;
    }

    // Client errors (4xx) are generally not retryable except for 408, 429
    if (errorString.contains('400') ||
        errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('404')) {
      return false;
    }

    // Default to non-retryable for unknown errors to prevent infinite loops
    return false;
  }
}
