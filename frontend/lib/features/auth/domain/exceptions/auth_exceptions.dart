/// Typed exception hierarchy for authentication errors
/// Replaces string-based error handling with proper type safety
abstract class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Rate limiting exception
class RateLimitException extends AuthException {
  const RateLimitException([String? message])
      : super(message ?? 'Too many login attempts. Please try again later.', code: 'RATE_LIMITED');
}

/// CSRF validation failure exception
class CsrfValidationException extends AuthException {
  const CsrfValidationException([String? message])
      : super(message ?? 'Security validation failed. Please try again.', code: 'CSRF_VALIDATION_FAILED');
}

/// OAuth cancelled by user exception
class OAuthCancelledException extends AuthException {
  const OAuthCancelledException([String? message])
      : super(message ?? 'Google login was cancelled', code: 'OAUTH_CANCELLED');
}

/// Network connectivity exception
class NetworkException extends AuthException {
  const NetworkException([String? message])
      : super(message ?? 'Network error. Please check your connection.', code: 'NETWORK_ERROR');
}

/// Invalid request exception
class InvalidRequestException extends AuthException {
  const InvalidRequestException([String? message])
      : super(message ?? 'Invalid login request. Please try again.', code: 'INVALID_REQUEST');
}

/// Authentication configuration exception
class AuthConfigException extends AuthException {
  const AuthConfigException([String? message])
      : super(message ?? 'Authentication configuration error.', code: 'AUTH_CONFIG_ERROR');
}

/// Session expired exception
class SessionExpiredException extends AuthException {
  const SessionExpiredException([String? message])
      : super(message ?? 'Your session has expired. Please sign in again.', code: 'SESSION_EXPIRED');
}

/// User not found exception
class UserNotFoundException extends AuthException {
  const UserNotFoundException([String? message]) : super(message ?? 'User account not found.', code: 'USER_NOT_FOUND');
}

/// Permission denied exception
class PermissionDeniedException extends AuthException {
  const PermissionDeniedException([String? message])
      : super(message ?? 'Permission denied. Insufficient privileges.', code: 'PERMISSION_DENIED');
}

/// Generic authentication failure
class AuthenticationFailedException extends AuthException {
  const AuthenticationFailedException([String? message])
      : super(message ?? 'Authentication failed. Please try again.', code: 'AUTH_FAILED');
}

/// Error severity levels for UI handling
enum ErrorSeverity {
  info, // User cancelled action - low severity
  warning, // Rate limit, temporary issue - medium severity
  error, // Authentication failed - high severity
  critical // System error - critical severity
}

/// Extension to get severity level from exception
extension AuthExceptionSeverity on AuthException {
  ErrorSeverity get severity {
    switch (runtimeType) {
      case OAuthCancelledException:
        return ErrorSeverity.info;
      case RateLimitException:
      case SessionExpiredException:
        return ErrorSeverity.warning;
      case NetworkException:
      case CsrfValidationException:
      case InvalidRequestException:
      case AuthenticationFailedException:
      case UserNotFoundException:
      case PermissionDeniedException:
        return ErrorSeverity.error;
      case AuthConfigException:
        return ErrorSeverity.critical;
      default:
        return ErrorSeverity.error;
    }
  }
}
