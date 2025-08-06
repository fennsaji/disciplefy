import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized authentication validation utilities
/// Reduces code duplication across auth_bloc and auth_service
class AuthValidator {
  /// Validates authentication success result with user data
  ///
  /// Used to standardize the validation pattern:
  /// `success && currentUser != null`
  static AuthValidationResult validateAuthenticationSuccess({
    required bool success,
    required User? currentUser,
    required String operationName,
  }) {
    if (!success) {
      return AuthValidationResult.failure(
        message: '$operationName failed',
        reason: AuthFailureReason.operationFailed,
      );
    }

    if (currentUser == null) {
      return AuthValidationResult.failure(
        message: '$operationName succeeded but user data is missing',
        reason: AuthFailureReason.missingUserData,
      );
    }

    return AuthValidationResult.success(user: currentUser);
  }

  /// Validates current authentication state
  ///
  /// Checks both Supabase user and stored auth type
  static Future<AuthStateValidationResult> validateCurrentAuthState({
    required User? supabaseUser,
    required Future<String?> Function() getUserType,
  }) async {
    // Check Supabase authentication first
    if (supabaseUser != null) {
      return AuthStateValidationResult.authenticated(
        user: supabaseUser,
        authType:
            supabaseUser.isAnonymous ? AuthType.anonymous : AuthType.supabase,
      );
    }

    // Check stored authentication
    try {
      final userType = await getUserType();
      if (userType != null && (userType == 'guest' || userType == 'google')) {
        return AuthStateValidationResult.authenticated(
          user: null, // No Supabase user for stored sessions
          authType: userType == 'guest' ? AuthType.anonymous : AuthType.google,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH VALIDATOR] Error checking stored auth state: $e');
      }
      return AuthStateValidationResult.error(
        message: 'Failed to validate authentication state: $e',
      );
    }

    return AuthStateValidationResult.unauthenticated();
  }

  /// Validates user type from storage
  ///
  /// Ensures the stored user type is valid
  static bool isValidUserType(String? userType) {
    if (userType == null) return false;
    return const ['guest', 'google', 'apple'].contains(userType);
  }

  /// Creates a standardized authentication error message
  static String getAuthErrorMessage(AuthFailureReason reason,
      [String? details]) {
    switch (reason) {
      case AuthFailureReason.operationFailed:
        return 'Authentication operation failed${details != null ? ': $details' : ''}';
      case AuthFailureReason.missingUserData:
        return 'Authentication succeeded but user data is missing${details != null ? ': $details' : ''}';
      case AuthFailureReason.invalidState:
        return 'Invalid authentication state${details != null ? ': $details' : ''}';
      case AuthFailureReason.configurationError:
        return 'Authentication configuration error${details != null ? ': $details' : ''}';
    }
  }
}

/// Result of authentication operation validation
class AuthValidationResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;
  final AuthFailureReason? failureReason;

  const AuthValidationResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
    this.failureReason,
  });

  factory AuthValidationResult.success({required User user}) =>
      AuthValidationResult._(
        isSuccess: true,
        user: user,
      );

  factory AuthValidationResult.failure({
    required String message,
    required AuthFailureReason reason,
  }) =>
      AuthValidationResult._(
        isSuccess: false,
        errorMessage: message,
        failureReason: reason,
      );
}

/// Result of authentication state validation
class AuthStateValidationResult {
  final AuthStateStatus status;
  final User? user;
  final AuthType? authType;
  final String? errorMessage;

  const AuthStateValidationResult._({
    required this.status,
    this.user,
    this.authType,
    this.errorMessage,
  });

  factory AuthStateValidationResult.authenticated({
    required User? user,
    required AuthType authType,
  }) =>
      AuthStateValidationResult._(
        status: AuthStateStatus.authenticated,
        user: user,
        authType: authType,
      );

  factory AuthStateValidationResult.unauthenticated() =>
      const AuthStateValidationResult._(
        status: AuthStateStatus.unauthenticated,
      );

  factory AuthStateValidationResult.error({required String message}) =>
      AuthStateValidationResult._(
        status: AuthStateStatus.error,
        errorMessage: message,
      );

  bool get isAuthenticated => status == AuthStateStatus.authenticated;
  bool get isUnauthenticated => status == AuthStateStatus.unauthenticated;
  bool get isError => status == AuthStateStatus.error;
}

/// Authentication failure reasons
enum AuthFailureReason {
  operationFailed,
  missingUserData,
  invalidState,
  configurationError,
}

/// Authentication state status
enum AuthStateStatus {
  authenticated,
  unauthenticated,
  error,
}

/// Authentication type
enum AuthType {
  supabase,
  google,
  anonymous,
}
