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
///
/// Features:
/// - Profile caching to prevent unnecessary API calls
/// - Smart cache invalidation on language/theme changes
/// - Efficient navigation without redundant profile fetching
class AuthStateProvider extends ChangeNotifier {
  late AuthBloc _authBloc;
  StreamSubscription<auth_states.AuthState>? _authStateSubscription;
  auth_states.AuthState _currentState = const auth_states.AuthInitialState();

  // Profile caching
  Map<String, dynamic>? _cachedProfile;
  DateTime? _profileCacheTime;
  String? _cachedUserId;
  static const Duration _profileCacheExpiry = Duration(minutes: 30);

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

      // Handle state-specific caching logic
      if (state is auth_states.AuthenticatedState) {
        // Cache the profile if it's available in the new state
        if (state.profile != null) {
          cacheProfile(state.user.id, state.profile);
        }
      } else if (state is auth_states.UnauthenticatedState) {
        // Clear cache on logout
        clearCache();
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
    clearCache();
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

  /// Get user profile if available (with caching)
  Map<String, dynamic>? get userProfile {
    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;

      // Return cached profile if available and fresh
      if (_cachedProfile != null &&
          _cachedUserId == authState.user.id &&
          _isProfileCacheFresh()) {
        if (kDebugMode) {
          print('📄 [AUTH STATE PROVIDER] Using cached profile');
        }
        return _cachedProfile;
      }

      // Return profile from auth state (may be null)
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

  /// Cache profile data for the current user
  void cacheProfile(String userId, Map<String, dynamic>? profile) {
    if (profile != null) {
      _cachedProfile = Map<String, dynamic>.from(profile);
      _profileCacheTime = DateTime.now();
      _cachedUserId = userId;

      if (kDebugMode) {
        print('📄 [AUTH STATE PROVIDER] Profile cached for user: $userId');
      }
    }
  }

  /// Check if cached profile is still fresh
  bool _isProfileCacheFresh() {
    if (_profileCacheTime == null) return false;

    final now = DateTime.now();
    final cacheAge = now.difference(_profileCacheTime!);
    return cacheAge < _profileCacheExpiry;
  }

  /// Check if we should fetch profile (cache is stale or missing)
  bool shouldFetchProfile(String userId) {
    // Always fetch if no cache
    if (_cachedProfile == null || _cachedUserId != userId) {
      return true;
    }

    // Fetch if cache is stale
    if (!_isProfileCacheFresh()) {
      if (kDebugMode) {
        print('📄 [AUTH STATE PROVIDER] Profile cache expired, should fetch');
      }
      return true;
    }

    if (kDebugMode) {
      print('📄 [AUTH STATE PROVIDER] Profile cache fresh, skipping fetch');
    }
    return false;
  }

  /// Invalidate profile cache (call when language/theme changes)
  void invalidateProfileCache() {
    _cachedProfile = null;
    _profileCacheTime = null;
    _cachedUserId = null;

    if (kDebugMode) {
      print('📄 [AUTH STATE PROVIDER] Profile cache invalidated');
    }
  }

  /// Clear all cached data (call on logout)
  void clearCache() {
    invalidateProfileCache();

    if (kDebugMode) {
      print('🧹 [AUTH STATE PROVIDER] All cache cleared');
    }
  }

  /// Debug information about current state
  String get debugInfo {
    final cacheInfo = _cachedProfile != null
        ? 'cached(${_isProfileCacheFresh() ? "fresh" : "stale"})'
        : 'no-cache';

    if (_currentState is auth_states.AuthenticatedState) {
      final authState = _currentState as auth_states.AuthenticatedState;
      return 'AuthenticatedState(isAnonymous: ${authState.isAnonymous}, '
          'userId: ${authState.user.id}, email: ${authState.user.email}, '
          'profile: $cacheInfo)';
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
