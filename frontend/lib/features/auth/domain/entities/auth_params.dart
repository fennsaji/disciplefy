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
class AuthDataStorageParams {
  final String accessToken;
  final String userType;
  final String? userId;

  const AuthDataStorageParams({
    required this.accessToken,
    required this.userType,
    this.userId,
  });

  /// Create params for Google authentication
  factory AuthDataStorageParams.google({
    required String accessToken,
    String? userId,
  }) =>
      AuthDataStorageParams(
        accessToken: accessToken,
        userType: 'google',
        userId: userId,
      );

  /// Create params for guest authentication
  factory AuthDataStorageParams.guest({
    required String accessToken,
    required String userId,
  }) =>
      AuthDataStorageParams(
        accessToken: accessToken,
        userType: 'guest',
        userId: userId,
      );

  /// Create params for Apple authentication
  factory AuthDataStorageParams.apple({
    required String accessToken,
    String? userId,
  }) =>
      AuthDataStorageParams(
        accessToken: accessToken,
        userType: 'apple',
        userId: userId,
      );
}
