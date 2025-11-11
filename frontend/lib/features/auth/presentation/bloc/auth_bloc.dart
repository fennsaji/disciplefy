import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/http_service.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/router/router_guard.dart';
import '../../../user_profile/data/services/user_profile_service.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../data/services/auth_service.dart';
import '../../domain/entities/auth_params.dart';
import '../../domain/exceptions/auth_exceptions.dart' as auth_exceptions;
import '../../domain/usecases/clear_user_data_usecase.dart';
import '../../domain/utils/auth_validator.dart';
import '../../../../core/di/injection_container.dart';
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
  Timer? _tokenValidationTimer;

  // Error recovery configuration
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(seconds: 30);

  AuthBloc({
    required AuthService authService,
    UserProfileService? userProfileService,
    ClearUserDataUseCase? clearUserDataUseCase,
  })  : _authService = authService,
        _userProfileService = userProfileService ?? sl<UserProfileService>(),
        _clearUserDataUseCase =
            clearUserDataUseCase ?? sl<ClearUserDataUseCase>(),
        super(const auth_states.AuthInitialState()) {
    // Register event handlers
    on<AuthInitializeRequested>(_onAuthInitialize);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<GoogleOAuthCallbackRequested>(_onGoogleOAuthCallback);
    on<AnonymousSignInRequested>(_onAnonymousSignIn);
    on<SessionCheckRequested>(_onSessionCheck);
    on<SessionValidationRequested>(_onSessionValidation);
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

    // Start automatic token validation for authenticated non-anonymous users
    _startTokenValidationTimer();
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    _httpAuthFailureSubscription.cancel();
    _tokenValidationTimer?.cancel();
    _authService.dispose();
    return super.close();
  }

  @override
  void onChange(Change<auth_states.AuthState> change) {
    super.onChange(change);
    // Log auth state transitions for debugging
    _logAuthStateTransition(change.currentState, change.nextState);
  }

  /// Initializes authentication state by checking current session
  /// Solution 3: Includes retry logic for transient storage failures
  Future<void> _onAuthInitialize(
    AuthInitializeRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(const auth_states.AuthLoadingState());

      // Retry session read attempts (Solution 3: handles transient storage failures)
      User? supabaseUser;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        if (kDebugMode) {
          print(
              '🔐 [AUTH INIT] Attempt ${retryCount + 1}/$maxRetries to read session');
        }

        try {
          // Check if user is already authenticated (Supabase)
          supabaseUser = _authService.currentUser;

          if (supabaseUser != null) {
            if (kDebugMode) {
              print('✅ [AUTH INIT] Session found on attempt ${retryCount + 1}');
            }
            break;
          }

          retryCount++;

          // Wait before retry with exponential backoff
          if (retryCount < maxRetries) {
            final delayMs = 500 * retryCount; // 500ms, 1000ms, 1500ms
            if (kDebugMode) {
              print(
                  '⏳ [AUTH INIT] No session found, retry $retryCount/$maxRetries in ${delayMs}ms...');
            }
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                '⚠️  [AUTH INIT] Session read attempt $retryCount failed: $e');
          }
          retryCount++;

          if (retryCount < maxRetries) {
            final delayMs = 500 * retryCount;
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }
      }

      // If session found after retries, proceed with authentication
      if (supabaseUser != null) {
        if (kDebugMode) {
          print('✅ [AUTH INIT] User authenticated: ${supabaseUser.id}');
        }

        // Load user profile data for Supabase users with caching
        final profile = await _getProfileWithCache(supabaseUser.id);

        emit(auth_states.AuthenticatedState(
          user: supabaseUser,
          profile: profile,
          isAnonymous: supabaseUser.isAnonymous,
        ));
        return;
      }

      // Log detailed failure information after all retries
      if (kDebugMode) {
        print(
            '🔐 [AUTH INIT] ⚠️  Session recovery failed after $maxRetries attempts');
        print('   Possible causes:');
        print('   1. Android Keystore was cleared by OS');
        print('   2. Storage corruption or read failure');
        print('   3. Session expired on backend');
        print('   4. First app launch (no session exists)');
      }

      // Check for anonymous session using async method with retry
      final isStorageAuthenticated =
          await _retryOperation(() => _authService.isAuthenticatedAsync());

      if (isStorageAuthenticated) {
        if (kDebugMode) {
          print(
              '🔐 [AUTH INIT] Storage indicates authentication - validating token...');
        }

        // Validate token before trusting storage
        final isTokenValid = await _authService.isTokenValid();

        if (!isTokenValid) {
          if (kDebugMode) {
            print(
                '🔐 [AUTH INIT] ⚠️  Token invalid or expired - clearing stale data');
          }

          // Clear stale data and force re-authentication
          await _clearUserDataUseCase.execute();
          emit(const auth_states.UnauthenticatedState());
          return;
        }

        if (kDebugMode) {
          print('🔐 [AUTH INIT] ✅ Token valid - creating anonymous session');
        }

        // Create mock user for anonymous session
        final user = _createAnonymousUser();

        emit(auth_states.AuthenticatedState(
          user: user,
          isAnonymous: true,
        ));
      } else {
        if (kDebugMode) {
          print('🔐 [AUTH INIT] No valid session - user is unauthenticated');
        }
        emit(const auth_states.UnauthenticatedState());
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔐 [AUTH INIT] ❌ Critical error during initialization: $e');
        print('🔐 [AUTH INIT] Stack trace: $stackTrace');
      }
      emit(const auth_states.AuthErrorState(
        message: 'Failed to initialize authentication',
      ));
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

          // Load user profile data with retry and caching
          final profile =
              await _retryOperation(() => _getProfileWithCache(user.id));

          // Invalidate router cache since auth status changed
          RouterGuard.invalidateLanguageSelectionCache();

          emit(auth_states.AuthenticatedState(
            user: user,
            profile: profile,
            isAnonymous: false,
          ));
        } else {
          // Handle validation failure
          final errorMessage =
              validationResult.errorMessage ?? 'Google sign-in failed';
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
          print(
              '🔐 [AUTH BLOC] 🚀 Starting Google OAuth callback processing...');
        }
        emit(const auth_states.AuthLoadingState());

        if (kDebugMode) {
          print('🔐 [AUTH BLOC] - Code: ${event.code.substring(0, 20)}...');
          print('🔐 [AUTH BLOC] - State: ${event.state}');
        }

        // Process the OAuth callback using AuthService with retry
        if (kDebugMode) {
          print(
              '🔐 [AUTH BLOC] 📞 Calling _authService.processGoogleOAuthCallback...');
        }
        final success =
            await _retryOperation(() => _authService.processGoogleOAuthCallback(
                  GoogleOAuthCallbackParams(
                    code: event.code,
                    state: event.state,
                  ),
                ));

        if (kDebugMode) {
          print('🔐 [AUTH BLOC] 📊 OAuth callback result: $success');
          print(
              '🔐 [AUTH BLOC] 📊 _authService.isAuthenticated: ${_authService.isAuthenticated}');
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
            print(
                '🔐 [AUTH BLOC] 👤 Retrieved user: ${user.id} (${user.email ?? "Anonymous"})');
            print('🔐 [AUTH BLOC] 👤 User isAnonymous: ${user.isAnonymous}');
          }

          // Load user profile data with retry and caching
          if (kDebugMode) {
            print('🔐 [AUTH BLOC] 📄 Loading user profile...');
          }
          final profile =
              await _retryOperation(() => _getProfileWithCache(user.id));
          if (kDebugMode) {
            print(
                '🔐 [AUTH BLOC] 📄 Profile loaded: ${profile != null ? "✅" : "❌"}');
          }

          if (kDebugMode) {
            print('🔐 [AUTH BLOC] ✅ Emitting AuthenticatedState...');
          }
          // Invalidate router cache since auth status changed
          RouterGuard.invalidateLanguageSelectionCache();

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
          final errorMessage = validationResult.errorMessage ??
              'OAuth callback processing failed';
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
        final success =
            await _retryOperation(() => _authService.signInAnonymously());

        if (success) {
          // Check authentication status using async method with retry
          final isAuthenticated =
              await _retryOperation(() => _authService.isAuthenticatedAsync());

          if (isAuthenticated) {
            // For anonymous users, create a mock user object since Supabase user is null
            final user = _authService.currentUser ?? _createAnonymousUser();

            // Invalidate router cache since auth status changed
            RouterGuard.invalidateLanguageSelectionCache();

            emit(auth_states.AuthenticatedState(
              user: user,
              isAnonymous: true,
            ));
          } else {
            throw const auth_exceptions.AuthenticationFailedException(
                'Anonymous sign-in failed');
          }
        } else {
          throw const auth_exceptions.AuthenticationFailedException(
              'Anonymous sign-in failed');
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
          print(
              '🔐 [AUTH BLOC] ✅ Valid session found: ${currentUser.email ?? currentUser.id}');
        }

        // Load user profile if not anonymous with caching
        Map<String, dynamic>? profile;
        if (!currentUser.isAnonymous) {
          profile = await _getProfileWithCache(currentUser.id);
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
      emit(auth_states.AuthErrorState(
          message: 'Session check failed: ${e.toString()}'));
    }
  }

  /// Handles session validation on app resume (Phase 3 monitoring)
  Future<void> _onSessionValidation(
    SessionValidationRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      if (kDebugMode) {
        print(
            '🔍 [SESSION VALIDATION] App resumed - validating current session...');
      }

      final currentState = state;

      // Only validate if currently authenticated
      if (currentState is auth_states.AuthenticatedState) {
        if (kDebugMode) {
          print(
              '🔍 [SESSION VALIDATION] Current user: ${currentState.isAnonymous ? "Anonymous" : currentState.user.email}');
        }

        // For non-anonymous users, validate Supabase session and token
        if (!currentState.isAnonymous) {
          final currentUser = _authService.currentUser;
          final currentSession = Supabase.instance.client.auth.currentSession;

          if (currentUser == null || currentSession == null) {
            if (kDebugMode) {
              print(
                  '🔍 [SESSION VALIDATION] ❌ No valid Supabase session found - clearing stale data');
            }

            // Clear stale data and force re-authentication
            await _clearUserDataUseCase.execute();
            emit(const auth_states.UnauthenticatedState());
            return;
          }

          // Validate token expiration and attempt refresh if needed
          // ANDROID FIX: Use ensureTokenValid() to attempt refresh instead of just checking
          final isTokenValid = await _authService.ensureTokenValid();
          if (!isTokenValid) {
            if (kDebugMode) {
              print(
                  '🔍 [SESSION VALIDATION] ❌ Token expired and refresh failed - triggering logout');
            }
            add(const TokenRefreshFailed(
                reason:
                    'Token expired and refresh failed during session validation'));
            return;
          }

          if (kDebugMode) {
            print(
                '🔍 [SESSION VALIDATION] ✅ Supabase session and token are valid');
          }
        } else {
          // For anonymous users, validate storage consistency
          final isStorageAuthenticated =
              await _authService.isAuthenticatedAsync();
          if (!isStorageAuthenticated) {
            if (kDebugMode) {
              print(
                  '🔍 [SESSION VALIDATION] ❌ Anonymous session storage inconsistent - clearing');
            }
            await _clearUserDataUseCase.execute();
            emit(const auth_states.UnauthenticatedState());
            return;
          }

          if (kDebugMode) {
            print(
                '🔍 [SESSION VALIDATION] ✅ Anonymous session storage is valid');
          }
        }
      } else {
        if (kDebugMode) {
          print(
              '🔍 [SESSION VALIDATION] Current state: ${currentState.runtimeType} - no validation needed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔍 [SESSION VALIDATION] ❌ Validation error: $e');
      }
      // Don't emit error state for validation failures to avoid disrupting UX
      // Let the current state persist and rely on other mechanisms to handle issues
    }
  }

  /// Handles sign-out flow
  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(const auth_states.AuthLoadingState());

      // Stop token validation when signing out
      _stopTokenValidationTimer();

      // Invalidate all caches on sign out
      try {
        final languageService = sl<LanguagePreferenceService>();
        languageService.invalidateLanguageCache();
        RouterGuard.invalidateLanguageSelectionCache();
        if (kDebugMode) {
          print(
              '📄 [AUTH BLOC] All caches invalidated on sign out (language + router)');
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              '📄 [AUTH BLOC] Warning: Could not invalidate caches on sign out: $e');
        }
      }

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
          if (kDebugMode) {
            print(
                '🔐 [AUTH BLOC] User signed in - Phone: ${user.phone != null}, Anonymous: ${user.isAnonymous}');
          }

          // For phone authentication, clear language selection cache for new users
          if (user.phone != null && !user.isAnonymous) {
            try {
              final languageService = sl<LanguagePreferenceService>();
              languageService.invalidateLanguageCache();
              RouterGuard.invalidateLanguageSelectionCache();
              if (kDebugMode) {
                print(
                    '📄 [AUTH BLOC] Language selection cache cleared for phone auth user');
              }
            } catch (e) {
              if (kDebugMode) {
                print(
                    '📄 [AUTH BLOC] Warning: Could not clear language cache: $e');
              }
            }
          }

          // Load user profile if authenticated (not anonymous) with caching
          final profile =
              user.isAnonymous ? null : await _getProfileWithCache(user.id);

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
          // Invalidate router cache since auth status changed
          RouterGuard.invalidateLanguageSelectionCache();

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
      if (e.toString().contains('flow_state_not_found') ||
          e.toString().contains('invalid flow state')) {
        if (kDebugMode) {
          print(
              'Ignoring Supabase flow state error - likely expired OAuth session');
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
      emit(const auth_states.AuthErrorState(
          message: 'Failed to delete account'));
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
        print('🚨 TOKEN EXPIRED: ${event.reason}');
        print('🚨 TOKEN EXPIRED: Clearing all stale data');

        // Log current storage state before cleanup for debugging
        try {
          final storedUserType = await _authService.getUserType();
          final storedUserId = await _authService.getUserId();
          final isOnboardingCompleted =
              await _authService.isOnboardingCompleted();
          print('🚨 Pre-cleanup storage state:');
          print('🚨   UserType: $storedUserType');
          print('🚨   UserId: $storedUserId');
          print('🚨   Onboarding completed: $isOnboardingCompleted');
        } catch (storageError) {
          print('🚨 Error reading storage state: $storageError');
        }
      }

      // Stop token validation when token expires
      _stopTokenValidationTimer();

      // Clear all authentication data using UseCase
      await _clearUserDataUseCase.execute();

      if (kDebugMode) {
        print(
            '🚨 TOKEN EXPIRED: Cleanup completed, emitting unauthenticated state');
      }

      // Emit unauthenticated state
      emit(const auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('🚨 Error handling token refresh failure: $e');
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
        print('🚨 FORCE LOGOUT: ${event.reason}');
        print('🚨 FORCE LOGOUT: Clearing all stale data');

        // Log current storage state before cleanup for debugging
        try {
          final storedUserType = await _authService.getUserType();
          final storedUserId = await _authService.getUserId();
          final isOnboardingCompleted =
              await _authService.isOnboardingCompleted();
          print('🚨 Pre-cleanup storage state:');
          print('🚨   UserType: $storedUserType');
          print('🚨   UserId: $storedUserId');
          print('🚨   Onboarding completed: $isOnboardingCompleted');
        } catch (storageError) {
          print('🚨 Error reading storage state: $storageError');
        }
      }

      emit(const auth_states.AuthLoadingState());

      // Stop token validation during force logout
      _stopTokenValidationTimer();

      // Clear all authentication data using UseCase
      await _clearUserDataUseCase.execute();

      if (kDebugMode) {
        print(
            '🚨 FORCE LOGOUT: Cleanup completed, emitting unauthenticated state');
      }

      // Emit unauthenticated state
      emit(const auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('🚨 Error during force logout: $e');
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
        emit(const auth_states.AuthErrorState(
            message: 'User not authenticated'));
        return;
      }

      await _userProfileService.upsertUserProfile(
        userId: user.id,
        languagePreference: event.languagePreference,
        themePreference: event.themePreference,
      );

      // Invalidate both profile and language cache
      final authStateProvider = sl<AuthStateProvider>();
      authStateProvider.invalidateProfileCache();

      // Also invalidate language and router cache since language preference changed
      try {
        final languageService = sl<LanguagePreferenceService>();
        languageService.invalidateLanguageCache();
        RouterGuard.invalidateLanguageSelectionCache();
        if (kDebugMode) {
          print(
              '📄 [AUTH BLOC] All caches invalidated after profile update (language + router)');
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              '📄 [AUTH BLOC] Warning: Could not invalidate caches after profile update: $e');
        }
      }

      // Fetch fresh profile data
      final profile = await _userProfileService.getUserProfileAsMap(user.id);

      // Cache the updated profile
      authStateProvider.cacheProfile(user.id, profile);

      emit(auth_states.AuthenticatedState(
        user: user,
        profile: profile,
        isAnonymous: user.isAnonymous,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('Profile update error: $e');
      }
      emit(const auth_states.AuthErrorState(
          message: 'Failed to update profile'));
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

  /// Efficiently get user profile with caching support
  /// Only fetches from API if cache is missing or stale
  Future<Map<String, dynamic>?> _getProfileWithCache(String userId) async {
    try {
      final authStateProvider = sl<AuthStateProvider>();

      // Check if we should fetch profile
      if (authStateProvider.shouldFetchProfile(userId)) {
        if (kDebugMode) {
          print('📄 [AUTH BLOC] Fetching profile for user: $userId');
        }

        // Fetch profile from API
        final profile = await _userProfileService.getUserProfileAsMap(userId);

        // Cache the profile in AuthStateProvider
        authStateProvider.cacheProfile(userId, profile);

        if (kDebugMode) {
          print('📄 [AUTH BLOC] Profile fetched and cached');
        }

        return profile;
      } else {
        if (kDebugMode) {
          print('📄 [AUTH BLOC] Using cached profile for user: $userId');
        }

        // Return cached profile
        return authStateProvider.userProfile;
      }
    } catch (e) {
      if (kDebugMode) {
        print('📄 [AUTH BLOC] Error getting profile with cache: $e');
      }
      return null;
    }
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
            print(
                '🚫 [AUTH RETRY] Error not retryable or max attempts reached');
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
          print(
              '🕐 [AUTH RETRY] Retrying in ${actualDelay.inMilliseconds}ms...');
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

  /// Starts periodic token validation and refresh for authenticated non-anonymous users
  /// CRITICAL FIX: Now proactively refreshes tokens before they expire
  void _startTokenValidationTimer() {
    _tokenValidationTimer?.cancel(); // Cancel existing timer if any

    _tokenValidationTimer =
        Timer.periodic(const Duration(minutes: 10), (_) async {
      try {
        if (state is auth_states.AuthenticatedState) {
          final authState = state as auth_states.AuthenticatedState;

          // Only validate tokens for non-anonymous users (they have Supabase sessions)
          if (!authState.isAnonymous) {
            if (kDebugMode) {
              print(
                  '🔄 [TOKEN VALIDATION] Periodic validation and refresh check...');
            }

            // CRITICAL FIX: Use ensureTokenValid instead of just checking
            // This will automatically refresh the token if it's expiring soon
            final isValid = await _authService.ensureTokenValid();

            if (!isValid) {
              if (kDebugMode) {
                print(
                    '🔄 [TOKEN VALIDATION] ❌ Token refresh failed - forcing logout');
              }
              add(const TokenRefreshFailed(
                  reason:
                      'Token expired and refresh failed during periodic validation'));
            } else if (kDebugMode) {
              print(
                  '🔄 [TOKEN VALIDATION] ✅ Token valid (refreshed if needed)');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('🔄 [TOKEN VALIDATION] Error during periodic validation: $e');
        }
        // Don't trigger logout on validation errors, just log them
      }
    });

    if (kDebugMode) {
      print(
          '🔄 [TOKEN VALIDATION] Automatic token validation and refresh started (10-minute intervals)');
    }
  }

  /// Stops the token validation timer
  void _stopTokenValidationTimer() {
    _tokenValidationTimer?.cancel();
    _tokenValidationTimer = null;
    if (kDebugMode) {
      print('🔄 [TOKEN VALIDATION] Automatic token validation stopped');
    }
  }

  /// Logs authentication state transitions for debugging and monitoring
  Future<void> _logAuthStateTransition(
      auth_states.AuthState from, auth_states.AuthState to) async {
    if (kDebugMode) {
      print('🔄 [AUTH TRANSITION] ${from.runtimeType} → ${to.runtimeType}');

      if (to is auth_states.AuthenticatedState) {
        final userInfo =
            to.isAnonymous ? 'Anonymous' : (to.user.email ?? to.user.id);
        print('🔄 [AUTH TRANSITION]   User: $userInfo');

        try {
          final storedUserType = await _authService.getUserType();
          final storedUserId = await _authService.getUserId();
          print('🔄 [AUTH TRANSITION]   Storage UserType: $storedUserType');
          print('🔄 [AUTH TRANSITION]   Storage UserId: $storedUserId');
        } catch (e) {
          print('🔄 [AUTH TRANSITION]   Storage read error: $e');
        }
      } else if (to is auth_states.AuthErrorState) {
        print('🔄 [AUTH TRANSITION]   Error: ${to.message}');
      } else if (to is auth_states.UnauthenticatedState) {
        print('🔄 [AUTH TRANSITION]   Cleared to unauthenticated state');
      }

      // Log critical transitions for monitoring
      if (from is auth_states.AuthenticatedState &&
          to is auth_states.UnauthenticatedState) {
        print('🚨 [AUTH MONITOR] CRITICAL: User logged out or session expired');
      }
      if (from is auth_states.UnauthenticatedState &&
          to is auth_states.AuthenticatedState) {
        print('✅ [AUTH MONITOR] SUCCESS: User authenticated');
      }
    }
  }
}
