import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../error/exceptions.dart';
import 'api_auth_helper.dart';
import '../utils/logger.dart';
import 'session_refresh.dart';

/// Centralized HTTP service with automatic 401 error handling and token refresh
class HttpService {
  static const int _maxRetries = 1;
  final http.Client _httpClient;
  bool _isDisposed = false;

  /// Stream controller for authentication failure events
  static final StreamController<String> _authFailureController =
      StreamController<String>.broadcast();

  /// Stream of authentication failure events
  static Stream<String> get authFailureStream => _authFailureController.stream;

  /// Signal an authentication failure from any layer (e.g. repository 401s).
  /// This triggers [ForceLogoutRequested] in AuthBloc, which clears Hive,
  /// Supabase session, and all local storage via [ClearUserDataUseCase].
  /// Prefer this over calling [Supabase.instance.client.auth.signOut()] directly.
  static void signalAuthFailure(String reason) {
    if (!_authFailureController.isClosed) {
      _authFailureController.add(reason);
    }
  }

  HttpService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Make an authenticated HTTP GET request with automatic 401 handling
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      await _makeRequest(
        () => _httpClient.get(Uri.parse(url), headers: headers),
        url,
        timeout: timeout,
      );

  /// Make an authenticated HTTP POST request with automatic 401 handling
  Future<http.Response> post(String url,
          {Map<String, String>? headers,
          String? body,
          Duration timeout = const Duration(seconds: 10)}) async =>
      await _makeRequest(
        () => _httpClient.post(Uri.parse(url), headers: headers, body: body),
        url,
        timeout: timeout,
      );

  /// Make an authenticated HTTP PUT request with automatic 401 handling
  Future<http.Response> put(String url,
          {Map<String, String>? headers, String? body}) async =>
      await _makeRequest(
        () => _httpClient.put(Uri.parse(url), headers: headers, body: body),
        url,
      );

  /// Make an authenticated HTTP PATCH request with automatic 401 handling
  Future<http.Response> patch(String url,
          {Map<String, String>? headers, String? body}) async =>
      await _makeRequest(
        () => _httpClient.patch(Uri.parse(url), headers: headers, body: body),
        url,
      );

  /// Make an authenticated HTTP DELETE request with automatic 401 handling
  Future<http.Response> delete(String url,
          {Map<String, String>? headers, String? body}) async =>
      await _makeRequest(
        () => _httpClient.delete(Uri.parse(url), headers: headers, body: body),
        url,
      );

  /// Core request method with automatic 401 handling and retry logic
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() requestFunction,
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_isDisposed) {
      throw const NetworkException(
        message: 'HTTP client has been disposed',
        code: 'CLIENT_DISPOSED',
      );
    }

    // Pre-request token validation to prevent CORS errors
    try {
      await ApiAuthHelper.validateTokenForRequest();
    } catch (e) {
      if (e is TokenValidationException) {
        // 'SESSION_UNVERIFIED' means we could not reach Supabase — offline, a
        // timeout, or a cold start where restoration had not finished. The
        // session may be perfectly valid, so the request fails and the user
        // stays signed in. Signing out here logged people out every time they
        // force-closed the app and reopened it before the network was back.
        if (e.code == 'SESSION_UNVERIFIED') {
          Logger.warning(
              '🔐 [HTTP] Session could not be verified (network) — keeping the user signed in');
          throw const NetworkException(
            message: 'Could not reach the server. Please try again.',
            code: 'SESSION_UNVERIFIED',
          );
        }

        Logger.error(
            '🔐 [HTTP] Pre-request token validation failed: ${e.message}');
        Logger.debug(
            '🔐 [HTTP] Triggering immediate logout to prevent CORS errors');
        await _handleAuthenticationFailure();
        throw AuthenticationException(
          message: 'Authentication token is invalid. Please login again.',
          code: 'TOKEN_INVALID',
        );
      }
      rethrow;
    }

    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        final response = await requestFunction().timeout(timeout);

        // Handle 401 Unauthorized - this should rarely happen now with pre-validation
        if (response.statusCode == 401) {
          Logger.debug(
              '🔐 [HTTP] 401 Unauthorized received for: $url (unexpected after pre-validation)');

          // Only attempt refresh if we have a session and haven't exceeded retries
          if (retryCount < _maxRetries && ApiAuthHelper.isAuthenticated) {
            Logger.debug('🔐 [HTTP] Attempting token refresh...');

            final outcome = await _refreshToken();
            if (outcome == SessionRefreshOutcome.refreshed) {
              Logger.debug(
                  '🔐 [HTTP] Token refresh successful, retrying request...');
              retryCount++;
              continue; // Retry the request
            }

            // Only a refusal from Supabase ends the session. A refresh that
            // never completed leaves the user signed in — the next request
            // retries, and the router refreshes on its own schedule.
            if (outcome == SessionRefreshOutcome.inconclusive) {
              Logger.warning(
                  '🔐 [HTTP] Refresh could not complete — keeping the user signed in');
              throw const NetworkException(
                message: 'Could not reach the server. Please try again.',
                code: 'SESSION_UNVERIFIED',
              );
            }

            Logger.error(
                '🔐 [HTTP] Refresh token rejected, logging out user...');
            await _handleAuthenticationFailure();
            throw const AuthenticationException(
              message: 'Session expired. Please login again.',
              code: 'SESSION_EXPIRED',
            );
          } else if (retryCount >= _maxRetries) {
            // Retries exhausted against a 401 we could not refresh past. The
            // session is not provably dead, so it is not destroyed here; the
            // caller sees a failed request and the router refreshes on its own
            // schedule.
            Logger.warning(
                '🔐 [HTTP] 401 persisted after $_maxRetries retries — keeping the user signed in');
            throw const NetworkException(
              message: 'Could not reach the server. Please try again.',
              code: 'SESSION_UNVERIFIED',
            );
          } else {
            // No session object in memory. That is NOT proof of a signed-out
            // user: on a resume or cold start, restoration may still be in
            // flight. This branch used to sign the user out on the spot without
            // attempting a refresh, which is how opening a shared link and then
            // navigating logged people out — the first authenticated request
            // after the jump ran before the session was back.
            //
            // Ask first. Only a refusal from Supabase ends the session.
            final outcome = await _refreshToken();
            if (outcome == SessionRefreshOutcome.refreshed) {
              Logger.debug('🔐 [HTTP] Session recovered, retrying request...');
              retryCount++;
              continue;
            }

            if (outcome == SessionRefreshOutcome.inconclusive) {
              Logger.warning(
                  '🔐 [HTTP] Session not restored yet — keeping the user signed in');
              throw const NetworkException(
                message: 'Could not reach the server. Please try again.',
                code: 'SESSION_UNVERIFIED',
              );
            }

            Logger.error(
                '🔐 [HTTP] Session refused by the server, logging out...');
            await _handleAuthenticationFailure();
            throw const AuthenticationException(
              message: 'Authentication required. Please login.',
              code: 'AUTHENTICATION_REQUIRED',
            );
          }
        }

        return response;
      } catch (e) {
        Logger.error('🚨 [HTTP] Request error for $url: $e');
        if (e is AuthenticationException) {
          rethrow;
        }

        // For non-auth errors, don't retry
        if (retryCount == 0) {
          throw NetworkException(
            message: 'Request failed: $e',
            code: 'REQUEST_FAILED',
          );
        }

        retryCount++;
      }
    }

    // This should never be reached, but just in case
    throw const NetworkException(
      message: 'Request failed after retries',
      code: 'REQUEST_FAILED',
    );
  }

  /// Attempt to refresh the authentication token
  Future<SessionRefreshOutcome> _refreshToken() async {
    try {
      final supabase = Supabase.instance.client;
      final currentSession = supabase.auth.currentSession;

      if (currentSession == null) {
        // No session in memory yet: on a cold start that is restoration still
        // running, not a signed-out user.
        Logger.debug('🔐 [HTTP] No current session to refresh');
        return SessionRefreshOutcome.inconclusive;
      }

      // Check if token is close to expiry (within 5 minutes)
      final now = DateTime.now();
      final expiryTime =
          DateTime.fromMillisecondsSinceEpoch(currentSession.expiresAt! * 1000);

      if (expiryTime.isAfter(now.add(const Duration(minutes: 5)))) {
        Logger.debug('🔐 [HTTP] Token is still valid, no refresh needed');
        return SessionRefreshOutcome.refreshed;
      }

      // Bounded, like the other refresh paths: a hung socket must not hold a
      // request open past its own timeout.
      final response = await supabase.auth
          .refreshSession()
          .timeout(const Duration(seconds: 5));

      if (response.session != null) {
        Logger.debug('🔐 [HTTP] Token refresh successful');
        ApiAuthHelper.logAuthState();
        return SessionRefreshOutcome.refreshed;
      }
      Logger.error('🔐 [HTTP] Token refresh returned no session');
      return SessionRefreshOutcome.rejected;
    } catch (e) {
      final outcome = classifySessionRefreshError(e);
      Logger.error('🔐 [HTTP] Token refresh error (${outcome.name}): $e');
      return outcome;
    }
  }

  /// Handle authentication failure by clearing session and data
  Future<void> _handleAuthenticationFailure() async {
    try {
      Logger.debug('🔐 [HTTP] Handling authentication failure...');

      // Notify the app about the authentication failure through the stream
      _authFailureController.add('Session expired or invalid');

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Clear any cached data
      await _clearUserData();

      Logger.error('🔐 [HTTP] Authentication failure handled');
    } catch (e) {
      Logger.debug(
          '🔐 [HTTP] Error during authentication failure handling: $e');
    }
  }

  /// Clear user-specific data from local storage
  Future<void> _clearUserData() async {
    try {
      // TODO: Clear any Hive boxes or other local storage
      // Add specific data clearing logic here as needed
      Logger.error('🔐 [HTTP] User data cleared');
    } catch (e) {
      Logger.debug('🔐 [HTTP] Error clearing user data: $e');
    }
  }

  /// Create headers with authentication and pre-validate token
  Future<Map<String, String>> createHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    // Pre-validate token before creating headers
    try {
      await ApiAuthHelper.validateTokenForRequest();
    } catch (e) {
      if (e is TokenValidationException) {
        Logger.error(
            '🔐 [HTTP] Header creation token validation failed: ${e.message}');
        throw AuthenticationException(
          message: 'Authentication token is invalid. Please login again.',
          code: 'TOKEN_INVALID',
        );
      }
      rethrow;
    }

    final headers = await ApiAuthHelper.getAuthHeaders();

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Dispose HTTP client
  void dispose() {
    if (!_isDisposed) {
      _httpClient.close();
      _isDisposed = true;
    }
  }

  /// Dispose static resources
  static void disposeStatic() {
    _authFailureController.close();
  }
}

/// Singleton instance of HttpService
class HttpServiceProvider {
  static HttpService? _instance;

  static HttpService get instance {
    _instance ??= HttpService();
    return _instance!;
  }

  static void dispose() {
    _instance?.dispose();
    _instance = null;
    HttpService.disposeStatic();
  }
}
