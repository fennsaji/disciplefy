/// Parameter objects for authentication service methods
/// Helps reduce long parameter lists and improve code readability
library;

/// Parameters for Google OAuth callback processing
class GoogleOAuthCallbackParams {
  final String code;
  final String? state;
  final String? error;
  final String? errorDescription;

  const GoogleOAuthCallbackParams({
    required this.code,
    this.state,
    this.error,
    this.errorDescription,
  });

  /// Create params from OAuth redirect URL query parameters
  factory GoogleOAuthCallbackParams.fromQueryParams(
          Map<String, String> params) =>
      GoogleOAuthCallbackParams(
        code: params['code'] ?? '',
        state: params['state'],
        error: params['error'],
        errorDescription: params['error_description'],
      );
}

/// Parameters for internal OAuth callback API call
class OAuthApiCallbackParams {
  final String code;
  final String? state;
  final String? idToken;

  const OAuthApiCallbackParams({
    required this.code,
    this.state,
    this.idToken,
  });
}

/// Parameters for storing authentication data
/// SECURITY FIX: Added session expiration and device binding
class AuthDataStorageParams {
  final String accessToken;
  final String userType;
  final String? userId;
  final DateTime? expiresAt; // SECURITY FIX: Track session expiration
  final String? deviceId; // SECURITY FIX: Bind session to device

  const AuthDataStorageParams({
    required this.accessToken,
    required this.userType,
    this.userId,
    this.expiresAt,
    this.deviceId,
  });

  /// Create params for Google authentication
  factory AuthDataStorageParams.google({
    required String accessToken,
    String? userId,
    DateTime? expiresAt,
    String? deviceId,
  }) =>
      AuthDataStorageParams(
        accessToken: accessToken,
        userType: 'google',
        userId: userId,
        expiresAt: expiresAt,
        deviceId: deviceId,
      );

  /// Create params for guest authentication
  factory AuthDataStorageParams.guest({
    required String accessToken,
    required String userId,
    DateTime? expiresAt,
    String? deviceId,
  }) =>
      AuthDataStorageParams(
        accessToken: accessToken,
        userType: 'guest',
        userId: userId,
        expiresAt: expiresAt,
        deviceId: deviceId,
      );

  /// Create params for Apple authentication
  factory AuthDataStorageParams.apple({
    required String accessToken,
    String? userId,
    DateTime? expiresAt,
    String? deviceId,
  }) =>
      AuthDataStorageParams(
        accessToken: accessToken,
        userType: 'apple',
        userId: userId,
        expiresAt: expiresAt,
        deviceId: deviceId,
      );
}
