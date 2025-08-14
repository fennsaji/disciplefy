import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart' as auth_states;

/// Unified authentication state provider that ensures consistent auth state
/// across all screens and components in the application.
///
/// This provider listens to AuthBloc state changes and provides a centralized
/// way to access current user information, preventing inconsistencies between
/// Home screen showing user name while Settings shows guest mode.
class AuthStateProvider extends ChangeNotifier {
  late AuthBloc _authBloc;
  StreamSubscription<auth_states.AuthState>? _authStateSubscription;
  auth_states.AuthState _currentState = const auth_states.AuthInitialState();

  /// Initialize the provider with an AuthBloc instance
  void initialize(AuthBloc authBloc) {
    _authBloc = authBloc;

    // Set initial state
    _currentState = _authBloc.state;

    // Listen to auth state changes
    _authStateSubscription = _authBloc.stream.listen((state) {
      if (kDebugMode) {
        print('🔄 [AUTH STATE PROVIDER] State changed: ${state.runtimeType}');
        if (state is auth_states.AuthenticatedState) {
          print(
              '🔄 [AUTH STATE PROVIDER] User: ${state.isAnonymous ? 'Anonymous' : state.user.email}');
        }
      }

      _currentState = state;
      notifyListeners();
    });

    if (kDebugMode) {
      print(
          '✅ [AUTH STATE PROVIDER] Initialized with state: ${_currentState.runtimeType}');
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    if (kDebugMode) {
      print('🧹 [AUTH STATE PROVIDER] Disposed');
    }
    super.dispose();
  }

  /// Get the current user's display name
  /// Returns 'Guest' for anonymous users or unauthenticated state
  String get currentUserName {
    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;

      if (authState.isAnonymous) {
        return 'Guest';
      }

      final user = authState.user;
      final displayName = user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'User';

      if (kDebugMode) {
        print('👤 [AUTH STATE PROVIDER] Display name: $displayName');
      }

      return displayName;
    }
    return 'Guest';
  }

  /// Check if user is currently authenticated (including anonymous)
  bool get isAuthenticated => _currentState is auth_states.AuthenticatedState;

  /// Check if current session is anonymous
  bool get isAnonymous {
    if (_currentState is auth_states.AuthenticatedState) {
      return (_currentState as auth_states.AuthenticatedState).isAnonymous;
    }
    return true; // Default to anonymous for unauthenticated state
  }

  /// Get current authentication state
  auth_states.AuthState get currentState => _currentState;

  /// Check if user is a signed-in (non-anonymous) user
  bool get isSignedInUser => isAuthenticated && !isAnonymous;

  /// Get user email if available
  String? get userEmail {
    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;
      if (!authState.isAnonymous) {
        return authState.user.email;
      }
    }
    return null;
  }

  /// Get user profile if available
  Map<String, dynamic>? get userProfile {
    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;
      return authState.profile;
    }
    return null;
  }

  /// Get current user ID
  String? get userId {
    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;
      return authState.user.id;
    }
    return null;
  }

  /// Debug information about current state
  String get debugInfo {
    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;
      return 'AuthenticatedState(isAnonymous: ${authState.isAnonymous}, '
          'userId: ${authState.user.id}, email: ${authState.user.email})';
    } else if (_currentState is auth_states.AuthLoadingState) {
      return 'AuthLoadingState';
    } else if (_currentState is auth_states.AuthErrorState) {
      final errorState = _currentState as auth_states.AuthErrorState;
      return 'AuthErrorState(message: ${errorState.message})';
    } else if (_currentState is auth_states.UnauthenticatedState) {
      return 'UnauthenticatedState';
    } else {
      return 'AuthInitialState';
    }
  }
}
