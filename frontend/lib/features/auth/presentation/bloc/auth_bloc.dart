import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart' as auth_states;

/// Authentication BLoC managing user authentication state
/// Follows Clean Architecture principles with proper separation of concerns
class AuthBloc extends Bloc<AuthEvent, auth_states.AuthState> {
  final AuthService _authService;
  late final StreamSubscription<AuthState> _authStateSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(auth_states.AuthInitialState()) {
    // Register event handlers
    on<AuthInitializeRequested>(_onAuthInitialize);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<GoogleOAuthCallbackRequested>(_onGoogleOAuthCallback);
    on<AnonymousSignInRequested>(_onAnonymousSignIn);
    on<SignOutRequested>(_onSignOut);
    on<AuthStateChanged>(_onAuthStateChanged);
    on<DeleteAccountRequested>(_onDeleteAccount);

    // Initialize authentication state
    add(const AuthInitializeRequested());

    // Listen to authentication state changes from Supabase
    _authStateSubscription = _authService.authStateChanges.listen(
      (supabaseAuthState) {
        add(AuthStateChanged(supabaseAuthState));
      },
    );
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    _authService.dispose();
    return super.close();
  }

  /// Initializes authentication state by checking current session
  Future<void> _onAuthInitialize(
    AuthInitializeRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(auth_states.AuthLoadingState());

      // Check if user is already authenticated
      if (_authService.isAuthenticated) {
        final user = _authService.currentUser;
        if (user != null) {
          // Load user profile data
          final profile = await _authService.getUserProfile();
          
          emit(auth_states.AuthenticatedState(
            user: user,
            profile: profile,
            isAnonymous: user.isAnonymous,
          ));
        } else {
          emit(auth_states.UnauthenticatedState());
        }
      } else {
        emit(auth_states.UnauthenticatedState());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auth initialization error: $e');
      }
      emit(auth_states.AuthErrorState(message: 'Failed to initialize authentication'));
    }
  }

  /// Handles Google sign-in flow
  Future<void> _onGoogleSignIn(
    GoogleSignInRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(auth_states.AuthLoadingState());

      // Attempt Google sign-in
      final success = await _authService.signInWithGoogle();
      
      if (success && _authService.isAuthenticated) {
        final user = _authService.currentUser!;
        
        // Create or update user profile
        await _authService.upsertUserProfile(
          languagePreference: 'en', // Default language
          themePreference: 'light',
        );
        
        // Load user profile data
        final profile = await _authService.getUserProfile();
        
        emit(auth_states.AuthenticatedState(
          user: user,
          profile: profile,
          isAnonymous: false,
        ));
      } else {
        emit(auth_states.AuthErrorState(message: 'Google sign-in failed'));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google sign-in error: $e');
      }
      
      // Handle specific error cases
      String errorMessage = 'Sign-in failed';
      
      if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
        errorMessage = 'Google login canceled';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('not configured')) {
        errorMessage = 'Google Sign-In not configured for this platform';
      } else if (e.toString().contains('Rate limited') || e.toString().contains('RATE_LIMITED')) {
        errorMessage = 'Too many login attempts. Please try again later.';
      } else if (e.toString().contains('CSRF_VALIDATION_FAILED')) {
        errorMessage = 'Security validation failed. Please try again.';
      } else if (e.toString().contains('Invalid login request') || e.toString().contains('INVALID_REQUEST')) {
        errorMessage = 'Invalid login request. Please try again.';
      }
      
      emit(auth_states.AuthErrorState(message: errorMessage));
    }
  }

  /// Handles Google OAuth callback with authorization code
  Future<void> _onGoogleOAuthCallback(
    GoogleOAuthCallbackRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(auth_states.AuthLoadingState());
      
      if (kDebugMode) {
        print('Processing Google OAuth callback with code: ${event.code.substring(0, 10)}...');
      }

      // Process the OAuth callback using AuthService
      final success = await _authService.processGoogleOAuthCallback(
        code: event.code,
        state: event.state,
      );

      if (success && _authService.isAuthenticated) {
        final user = _authService.currentUser;
        if (user != null) {
          // Load user profile data
          final profile = await _authService.getUserProfile();
          
          emit(auth_states.AuthenticatedState(
            user: user,
            isAnonymous: user.isAnonymous,
            profile: profile,
          ));
          
          if (kDebugMode) {
            print('Google OAuth callback processed successfully');
          }
        } else {
          throw Exception('Authentication succeeded but user is null');
        }
      } else {
        throw Exception('OAuth callback processing failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google OAuth callback error: $e');
      }
      
      // Handle specific error cases
      String errorMessage = 'Authentication failed';
      
      if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
        errorMessage = 'Google login was cancelled';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('Rate limited') || e.toString().contains('RATE_LIMITED')) {
        errorMessage = 'Too many login attempts. Please try again later.';
      } else if (e.toString().contains('CSRF_VALIDATION_FAILED')) {
        errorMessage = 'Security validation failed. Please try again.';
      } else if (e.toString().contains('Invalid login request') || e.toString().contains('INVALID_REQUEST')) {
        errorMessage = 'Invalid login request. Please try again.';
      } else if (e.toString().contains('OAUTH_EXCHANGE_FAILED')) {
        errorMessage = 'Google authentication failed. Please try again.';
      } else if (e.toString().contains('OAUTH_SESSION_FAILED')) {
        errorMessage = 'Failed to create session. Please try again.';
      }
      
      emit(auth_states.AuthErrorState(message: errorMessage));
    }
  }

  /// Handles anonymous sign-in flow
  Future<void> _onAnonymousSignIn(
    AnonymousSignInRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(auth_states.AuthLoadingState());

      // Attempt anonymous sign-in
      final success = await _authService.signInAnonymously();
      
      if (success && _authService.isAuthenticated) {
        final user = _authService.currentUser!;
        
        emit(auth_states.AuthenticatedState(
          user: user,
          profile: null, // Anonymous users don't have profiles
          isAnonymous: true,
        ));
      } else {
        emit(auth_states.AuthErrorState(message: 'Anonymous sign-in failed'));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Anonymous sign-in error: $e');
      }
      emit(auth_states.AuthErrorState(message: 'Failed to continue as guest'));
    }
  }

  /// Handles sign-out flow
  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<auth_states.AuthState> emit,
  ) async {
    try {
      emit(auth_states.AuthLoadingState());

      // Sign out from authentication service
      await _authService.signOut();
      
      emit(auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('Sign-out error: $e');
      }
      emit(auth_states.AuthErrorState(message: 'Failed to sign out'));
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
          final profile = user.isAnonymous ? null : await _authService.getUserProfile();
          
          emit(auth_states.AuthenticatedState(
            user: user,
            profile: profile,
            isAnonymous: user.isAnonymous,
          ));
        }
      } else if (authState.event == AuthChangeEvent.signedOut) {
        emit(auth_states.UnauthenticatedState());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auth state change error: $e');
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
      emit(auth_states.AuthLoadingState());

      // Delete account and all associated data
      await _authService.deleteAccount();
      
      emit(auth_states.UnauthenticatedState());
    } catch (e) {
      if (kDebugMode) {
        print('Delete account error: $e');
      }
      emit(auth_states.AuthErrorState(message: 'Failed to delete account'));
    }
  }

  /// Checks if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      return await _authService.isCurrentUserAdmin();
    } catch (e) {
      if (kDebugMode) {
        print('Admin check error: $e');
      }
      return false;
    }
  }

  /// Updates user profile
  Future<void> updateUserProfile({
    required String languagePreference,
    String themePreference = 'light',
  }) async {
    try {
      await _authService.upsertUserProfile(
        languagePreference: languagePreference,
        themePreference: themePreference,
      );
      
      // Refresh auth state to get updated profile
      if (_authService.isAuthenticated) {
        final user = _authService.currentUser!;
        final profile = await _authService.getUserProfile();
        
        emit(auth_states.AuthenticatedState(
          user: user,
          profile: profile,
          isAnonymous: user.isAnonymous,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Profile update error: $e');
      }
      emit(auth_states.AuthErrorState(message: 'Failed to update profile'));
    }
  }
}